import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/core/services/giphy_service.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Bottom sheet for searching and selecting Giphy GIFs.
class GifPickerSheet extends ConsumerStatefulWidget {
  final void Function(GiphyGif gif) onGifSelected;

  const GifPickerSheet({super.key, required this.onGifSelected});

  @override
  ConsumerState<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends ConsumerState<GifPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<GiphyGif>? _searchResults;
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isSearching = true;
        _error = null;
      });
      try {
        final results = await ref.read(giphyServiceProvider).search(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Failed to search GIFs. Try again later.';
            _isSearching = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine which list to show: search results or trending
    final trendingAsync = ref.watch(trendingGifsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // 75% of screen height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: 12.h, bottom: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search Giphy...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.featureBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // Content area
          Expanded(
            child: _isSearching
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _error != null
                ? Center(child: Text(_error!))
                : _searchResults != null
                ? _buildGrid(_searchResults!)
                : trendingAsync.when(
                    data: (gifs) => _buildGrid(gifs),
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    error: (e, _) =>
                        Center(child: Text('Failed to load trending GIFs: $e')),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<GiphyGif> gifs) {
    if (gifs.isEmpty) {
      return const Center(child: Text('No GIFs found.'));
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        childAspectRatio: 1.0, // force square or roughly square
      ),
      itemCount: gifs.length,
      itemBuilder: (context, index) {
        final gif = gifs[index];
        return GestureDetector(
          onTap: () => widget.onGifSelected(gif),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: CachedNetworkImage(
              imageUrl: gif.url,
              memCacheWidth: 400,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.withValues(alpha: 0.1),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.withValues(alpha: 0.1),
                child: const Icon(Icons.broken_image_rounded),
              ),
            ),
          ),
        );
      },
    );
  }
}
