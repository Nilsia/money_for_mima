enum SortAction { allTransactions, flaggedTransactions, unFlaggedTransactions }

class TableSortItem {
  final SortAction sortAction;
  final String dropDownName;

  TableSortItem(this.sortAction, this.dropDownName);
}
