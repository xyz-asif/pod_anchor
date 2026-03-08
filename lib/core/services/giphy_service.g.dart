// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'giphy_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$giphyServiceHash() => r'67a9a03ffdc9e9566a0487fa7f430e57f3f5d21f';

/// See also [giphyService].
@ProviderFor(giphyService)
final giphyServiceProvider = AutoDisposeProvider<GiphyService>.internal(
  giphyService,
  name: r'giphyServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$giphyServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GiphyServiceRef = AutoDisposeProviderRef<GiphyService>;
String _$trendingGifsHash() => r'f6b4862af03e760b98b3775c81445c8e8317d1d2';

/// See also [trendingGifs].
@ProviderFor(trendingGifs)
final trendingGifsProvider = AutoDisposeFutureProvider<List<GiphyGif>>.internal(
  trendingGifs,
  name: r'trendingGifsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$trendingGifsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TrendingGifsRef = AutoDisposeFutureProviderRef<List<GiphyGif>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
