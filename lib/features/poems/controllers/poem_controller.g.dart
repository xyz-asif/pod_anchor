// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poem_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myPoemsControllerHash() => r'17088e4afd4b1654f8c3e92981f6933597d4bfbe';

/// My poems list — keepAlive so it persists across navigation
///
/// Copied from [MyPoemsController].
@ProviderFor(MyPoemsController)
final myPoemsControllerProvider =
    AsyncNotifierProvider<MyPoemsController, List<PoemModel>>.internal(
      MyPoemsController.new,
      name: r'myPoemsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$myPoemsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MyPoemsController = AsyncNotifier<List<PoemModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
