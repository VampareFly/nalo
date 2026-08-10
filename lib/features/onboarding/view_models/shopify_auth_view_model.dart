import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/core/network/dio_provider.dart';
import 'package:tester_kit/features/onboarding/services/shopify_auth_service.dart';

final shopifyAuthServiceProvider = Provider<ShopifyAuthService>(
  (ref) => ShopifyAuthService(dio: ref.watch(dioProvider)),
);

final shopifyAuthViewModelProvider =
    NotifierProvider.autoDispose<ShopifyAuthViewModel, ShopifyAuthState>(
      ShopifyAuthViewModel.new,
    );

class ShopifyAuthState {
  const ShopifyAuthState({
    this.isLoading = false,
    this.isLoggingOut = false,
    this.accessToken,
    this.idToken,
    this.accessTokenExpirationDateTime,
  });

  final bool isLoading;
  final bool isLoggingOut;
  final String? accessToken;
  final String? idToken;
  final DateTime? accessTokenExpirationDateTime;

  bool get isLoggedIn => accessToken != null && idToken != null;
  bool get isBusy => isLoading || isLoggingOut;
}

class ShopifyAuthViewModel extends Notifier<ShopifyAuthState> {
  @override
  ShopifyAuthState build() => const ShopifyAuthState();

  Future<String?> login() async {
    if (state.isBusy) return null;
    state = const ShopifyAuthState(isLoading: true);

    try {
      final result = await ref.read(shopifyAuthServiceProvider).login();
      state = ShopifyAuthState(
        accessToken: result.accessToken,
        idToken: result.idToken,
        accessTokenExpirationDateTime: result.accessTokenExpirationDateTime,
      );
      return null;
    } on FlutterAppAuthUserCancelledException {
      state = const ShopifyAuthState();
      return 'Shopify login was cancelled';
    } on ShopifyAuthException catch (error) {
      state = const ShopifyAuthState();
      return error.message;
    } on FlutterAppAuthPlatformException catch (error) {
      state = const ShopifyAuthState();
      return error.message ?? 'Unable to log in with Shopify';
    } catch (_) {
      state = const ShopifyAuthState();
      return 'Unable to log in with Shopify';
    }
  }

  Future<String?> logout() async {
    final idToken = state.idToken;
    if (idToken == null) return 'No active Shopify session';
    if (state.isBusy) return null;

    final authenticatedState = state;
    state = ShopifyAuthState(
      isLoggingOut: true,
      accessToken: state.accessToken,
      idToken: state.idToken,
      accessTokenExpirationDateTime: state.accessTokenExpirationDateTime,
    );

    try {
      await ref
          .read(shopifyAuthServiceProvider)
          .logout(idToken: idToken);
      state = const ShopifyAuthState();
      return null;
    } on ShopifyAuthException catch (error) {
      state = authenticatedState;
      return error.message;
    } catch (_) {
      state = authenticatedState;
      return 'Unable to log out from Shopify';
    }
  }
}
