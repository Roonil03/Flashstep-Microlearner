import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// Status-based messages never display proxy HTML, SQL errors or response bodies.
String apiErrorMessage(
  http.Response response, {
  String fallback = 'The request could not be completed. Please try again.',
}) {
  switch (response.statusCode) {
    case 401:
      return 'Your session is invalid or expired. Please sign in again.';
    case 403:
      return 'You do not have permission to complete this action.';
    case 404:
      return 'The requested item could not be found. Refresh and try again.';
    case 409:
      return 'This item changed or already exists. Refresh and try again.';
    case 413:
      return 'This request is too large. Please use a smaller batch.';
    case 429:
      return 'Too many requests. Please wait a minute and try again.';
  }
  if (response.statusCode >= 500) {
    return 'The server is temporarily unavailable. Please try again shortly.';
  }
  if (response.statusCode == 400 || response.statusCode == 422) {
    try {
      final data = jsonDecode(response.body);
      final message = data is Map ? data['error'] : null;
      const allowed = {
        'invalid credentials',
        'invalid old password',
        'password must be at least 8 characters',
        'password must be between 8 and 72 bytes',
        'username, email and password are required',
        'front and back are required',
        'title is required',
        'a deck can contain at most 50 cards',
        'you already own this public deck',
      };
      if (message is String && allowed.contains(message)) return message;
    } catch (_) {}
    return 'Please check the entered values and try again.';
  }
  return fallback;
}

class ApiRequestException implements Exception {
  final String message;
  const ApiRequestException(this.message);
  @override
  String toString() => message;
}

String networkErrorMessage(Object error) {
  if (error is ApiRequestException) return error.message;
  if (error is StateError) {
    const allowed = {
      'Deck title cannot be empty.',
      'Card front and back are required.',
      'A deck can contain at most 50 cards.',
      'This deck is already full.',
      'This card has been permanently deleted and cannot be restored.',
      'This deck has been permanently deleted and cannot be restored.',
    };
    if (allowed.contains(error.message)) return error.message;
    if (error.message == 'Deck not found.' ||
        error.message == 'Card not found.') {
      return 'This item is no longer available. Refresh your decks and try again.';
    }
    if (error.message == 'No signed-in user found.' ||
        error.message == 'No active session found. Please sign in again.' ||
        error.message == 'You must be signed in to browse public decks.' ||
        error.message == 'You must be signed in to download a public deck.') {
      return 'Please sign in again to continue.';
    }
  }
  if (error is TimeoutException) {
    return 'The request timed out. Please try again.';
  }
  if (error is SocketException || error is http.ClientException) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  return 'The request could not be completed. Please try again.';
}
