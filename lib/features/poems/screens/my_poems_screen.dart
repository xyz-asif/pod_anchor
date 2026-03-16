import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';

class MyPoemsScreen extends ConsumerStatefulWidget {
  const MyPoemsScreen({super.key});

  @override
  ConsumerState<MyPoemsScreen> createState() => _MyPoemsScreenState();
}

class _MyPoemsScreenState extends ConsumerState<MyPoemsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(myPoemsControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _deletePoem(PoemModel poem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete poem?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(poemRepoProvider).deletePoem(poem.id);
      ref.read(myPoemsControllerProvider.notifier).removePoem(poem.id);
      if (mounted) AppSnackbar.show(context, message: 'Poem deleted', type: SnackbarType.success);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: 'Failed to delete', type: SnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myPoemsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Poems', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(), style: TextStyle(color: Colors.red, fontSize: 14.sp)),
              TextButton(
                onPressed: () => ref.read(myPoemsControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (poems) {
          if (poems.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded, size: 64.r, color: AppTheme.textLightColor),
                  SizedBox(height: 12.h),
                  Text('No poems yet', style: TextStyle(fontSize: 16.sp, color: AppTheme.textMediumColor)),
                  SizedBox(height: 4.h),
                  Text('Tap + to write your first poem', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(myPoemsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: poems.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderColor),
              itemBuilder: (context, index) {
                final poem = poems[index];
                return _PoemTile(
                  poem: poem,
                  onTap: () => context.push('/editor', extra: poem),
                  onDelete: () => _deletePoem(poem),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/editor'),
        backgroundColor: AppTheme.primaryColor,
        child: Icon(Icons.edit_rounded, color: Colors.white, size: 24.r),
      ),
    );
  }
}

class _PoemTile extends StatelessWidget {
  final PoemModel poem;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PoemTile({required this.poem, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              poem.title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (poem.isDraft)
            Container(
              margin: EdgeInsets.only(left: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text('Draft', style: TextStyle(fontSize: 11.sp, color: AppTheme.textMediumColor)),
            ),
          if (poem.isOriginal)
            Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Icon(Icons.copyright_rounded, size: 14.r, color: AppTheme.primaryColor),
            ),
          if (poem.hasAudio)
            Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Icon(Icons.mic_rounded, size: 14.r, color: AppTheme.textMediumColor),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4.h),
          Text(
            poem.plainText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor),
          ),
          if (poem.hashtags.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Wrap(
              spacing: 4.w,
              children: poem.hashtags.take(3).map((t) => Text(
                '#$t',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor),
              )).toList(),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
        icon: Icon(Icons.more_vert_rounded, size: 20.r, color: AppTheme.textMediumColor),
      ),
    );
  }
}
