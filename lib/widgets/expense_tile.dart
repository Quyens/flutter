import 'package:flutter/material.dart';
import '../models/expense_model.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('expense_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        if (onDelete != null) onDelete!();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: expense.category.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              expense.category.icon,
              color: expense.category.color,
              size: 24,
            ),
          ),
          title: Text(
            expense.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: expense.category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      expense.category.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: expense.category.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    expense.formattedDateOnly,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              if (expense.note != null && expense.note!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  expense.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          trailing: Text(
            '-${expense.formattedAmount}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE11D48),
            ),
          ),
        ),
      ),
    );
  }
}
