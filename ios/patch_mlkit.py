import os
import glob
import subprocess
import struct
import shutil
import tempfile

def restore_from_cache_if_needed(binary_path, fw_name):
    cache_root = os.path.expanduser('~/Library/Caches/CocoaPods/Pods/Release')
    for root, dirs, files in os.walk(cache_root):
        if fw_name in files:
            cached = os.path.join(root, fw_name)
            if 'Frameworks' in cached:
                print(f"Restoring clean copy of {fw_name} from {cached}")
                shutil.copy2(cached, binary_path)
                return True
    return False

def patch_macho_bytes(data, offset):
    if offset + 32 > len(data):
        return False
    magic = struct.unpack('<I', data[offset:offset+4])[0]
    if magic != 0xfeedfacf:
        return False
    
    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack('<IIIIIIII', data[offset:offset+32])
    cmd_offset = offset + 32
    modified = False
    
    for _ in range(ncmds):
        if cmd_offset + 8 > len(data):
            break
        cmd, cmdsize = struct.unpack('<II', data[cmd_offset:cmd_offset+8])
        if cmd == 0x32: # LC_BUILD_VERSION
            if cmd_offset + 24 <= len(data):
                platform = struct.unpack('<I', data[cmd_offset+8:cmd_offset+12])[0]
                if platform == 2: # PLATFORM_IOS
                    struct.pack_into('<I', data, cmd_offset+8, 7) # PLATFORM_IOSSIMULATOR
                    modified = True
        cmd_offset += cmdsize
    return modified

def patch_archive_in_place(ar_path):
    with open(ar_path, 'rb') as f:
        data = bytearray(f.read())
    
    if not data.startswith(b'!<arch>\n'):
        # Check if direct Mach-O
        if patch_macho_bytes(data, 0):
            with open(ar_path, 'wb') as f:
                f.write(data)
            return 1
        return 0
    
    offset = 8
    patched_count = 0
    
    while offset < len(data):
        if offset + 60 > len(data):
            break
        hdr = data[offset:offset+60]
        size_str = hdr[48:58].decode('ascii', errors='ignore').strip()
        try:
            size = int(size_str)
        except ValueError:
            break
        
        member_name = hdr[:16].decode('ascii', errors='ignore').strip()
        data_offset = offset + 60
        
        macho_offset = data_offset
        if member_name.startswith('#1/'):
            try:
                namelen = int(member_name[3:])
                macho_offset = data_offset + namelen
            except ValueError:
                pass
        
        if patch_macho_bytes(data, macho_offset):
            patched_count += 1
            
        offset = data_offset + size + (size % 2)
        
    with open(ar_path, 'wb') as f:
        f.write(data)
    
    if patched_count > 0:
        subprocess.run(['ranlib', ar_path], check=True)
    return patched_count

def patch_framework_binary(binary_path):
    fw_name = os.path.basename(binary_path)
    restore_from_cache_if_needed(binary_path, fw_name)
    
    res = subprocess.run(['lipo', '-info', binary_path], capture_output=True, text=True)
    if res.returncode != 0:
        return
    info = res.stdout
    if 'arm64' not in info:
        return
    
    has_x86_64 = 'x86_64' in info
    tmpdir = tempfile.mkdtemp()
    try:
        arm64_path = os.path.join(tmpdir, 'arm64.a')
        subprocess.run(['lipo', '-thin', 'arm64', binary_path, '-output', arm64_path], check=True)
        
        count = patch_archive_in_place(arm64_path)
        print(f"  {fw_name}: patched {count} arm64 load commands to iOS Simulator in-place.")
        
        if has_x86_64:
            x86_path = os.path.join(tmpdir, 'x86_64.a')
            subprocess.run(['lipo', '-thin', 'x86_64', binary_path, '-output', x86_path], check=True)
            subprocess.run(['lipo', '-create', x86_path, arm64_path, '-output', binary_path], check=True)
        else:
            shutil.copy2(arm64_path, binary_path)
            
        print(f"  Successfully patched {fw_name} universal binary!")
    finally:
        shutil.rmtree(tmpdir)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    pods_dir = os.path.join(script_dir, 'Pods')
    
    targets = [
        'MLKitVision',
        'MLKitCommon',
        'MLKitTextRecognitionCommon',
        'MLImage',
        'MLKitTextRecognition'
    ]
    
    for t in targets:
        matches = glob.glob(os.path.join(pods_dir, '**', f'{t}.framework', t), recursive=True)
        for binary in matches:
            if os.path.isfile(binary) and not os.path.islink(binary):
                patch_framework_binary(binary)

if __name__ == '__main__':
    main()
