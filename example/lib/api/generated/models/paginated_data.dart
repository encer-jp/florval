/// Paginated data container for cursor-based pagination.
///
/// [T] is the item type (e.g. Pet, Comment).
/// [P] is the raw page type returned by the API (e.g. SearchPetsPage, CommentPage).
class PaginatedData<T, P> {
  /// The accumulated items across all loaded pages.
  final List<T> items;

  /// The cursor for the next page. Null if no more pages.
  final String? nextCursor;

  /// Whether more pages are available.
  final bool hasMore;

  /// The raw page data from the last API response.
  /// Use this to access API-specific fields (e.g. totalCount).
  final P lastPage;

  const PaginatedData({
    required this.items,
    this.nextCursor,
    this.hasMore = true,
    required this.lastPage,
  });
}
