import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web/web_browser.dart' as browser;
import 'video/video_upload.dart';

/// Notifies mounted screens when recording metadata or video status changes.
final ValueNotifier<int> recordingsChanged = ValueNotifier<int>(0);

void notifyRecordingsChanged() {
  recordingsChanged.value++;
}

String _describeVideoUploadFailure(Object error, String stage) {
  if (error is DioException) {
    final response = error.response;
    final responseData = response?.data;
    final detail = responseData is Map
        ? responseData['detail']?.toString()
        : null;
    if (response != null) {
      return '$stage failed (HTTP ${response.statusCode})'
          '${detail == null || detail.isEmpty ? '' : ': $detail'}';
    }

    if (kIsWeb && stage == 'Uploading video to Cloudflare R2') {
      return '$stage failed in the browser. Check that the R2 bucket CORS rule '
          'allows origin ${Uri.base.origin}, method PUT, and the Content-Type '
          'header. The browser could not complete the cross-origin request.';
    }

    return '$stage failed (${error.type.name}). Check the network connection.';
  }

  return '$stage failed: $error';
}

String describeApiError(Object error) {
  if (error is DioException) {
    final response = error.response;
    final payload = response?.data;
    final detail = payload is Map ? payload['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List) {
      final messages = detail
          .whereType<Map>()
          .map((item) => item['msg']?.toString())
          .whereType<String>()
          .where((message) => message.isNotEmpty)
          .toList();
      if (messages.isNotEmpty) return messages.join('; ');
    }
    if (response != null) {
      return 'Request failed (HTTP ${response.statusCode}).';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Cannot reach the SignBridge server at ${error.requestOptions.baseUrl}. Check that the server is running and this device can reach its address.';
    }
    return 'Network request failed (${error.type.name}).';
  }
  return error.toString();
}

class ApiClient {
  static const _configuredBaseUrl = String.fromEnvironment(
    'SIGNBRIDGE_API_BASE_URL',
  );

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors - try to refresh token
          final requestPath = error.requestOptions.path;
          final isAuthRequest =
              requestPath.endsWith('/auth/login') ||
              requestPath.endsWith('/auth/register') ||
              requestPath.endsWith('/auth/refresh');
          if (error.response?.statusCode == 401 && !isAuthRequest) {
            try {
              final refreshToken = await _storage.read(key: 'refresh_token');
              if (refreshToken != null) {
                final response = await _dio.post(
                  '/auth/refresh',
                  data: {'refresh_token': refreshToken},
                );

                final newAccessToken = response.data['access_token'];
                final newRefreshToken = response.data['refresh_token'];

                await _storage.write(
                  key: 'access_token',
                  value: newAccessToken,
                );
                await _storage.write(
                  key: 'refresh_token',
                  value: newRefreshToken,
                );

                // Retry the original request with new token
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';
                final retryResponse = await _dio.fetch(opts);
                return handler.resolve(retryResponse);
              }
            } catch (e) {
              // Refresh failed, clear tokens and redirect to login
              await _storage.delete(key: 'access_token');
              await _storage.delete(key: 'refresh_token');
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }
    // Android emulators reach the development host through 10.0.2.2. A real
    // phone must use a LAN/HTTPS URL supplied with SIGNBRIDGE_API_BASE_URL.
    final host = kIsWeb && Uri.base.host.isNotEmpty
        ? Uri.base.host
        : defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    final scheme = kIsWeb && Uri.base.scheme == 'https' ? 'https' : 'http';
    return Uri(
      scheme: scheme,
      host: host,
      port: 8000,
    ).resolve('/api/v1').toString();
  }

  String resolveFileUrl(String fileUrl) {
    final parsed = Uri.parse(fileUrl);
    if (parsed.hasScheme) return fileUrl;
    final apiUri = Uri.parse(baseUrl);
    final origin = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.port,
    );
    return origin.resolve(fileUrl).toString();
  }

  Dio get dio => _dio;

  // Auth methods
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    // Store tokens
    await _storage.write(
      key: 'access_token',
      value: response.data['access_token'],
    );
    await _storage.write(
      key: 'refresh_token',
      value: response.data['refresh_token'],
    );

    return response.data;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  // Signer methods
  Future<Map<String, dynamic>> createSigner(
    Map<String, dynamic> signerData,
  ) async {
    final response = await _dio.post('/signers/', data: signerData);
    return response.data;
  }

  Future<List<Map<String, dynamic>>> listSigners({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/signers/',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getSigners({
    int skip = 0,
    int limit = 100,
  }) async {
    return listSigners(skip: skip, limit: limit);
  }

  Future<Map<String, dynamic>> getSigner(String signerId) async {
    final response = await _dio.get('/signers/$signerId');
    return response.data;
  }

  Future<Map<String, dynamic>> recordConsent(
    String signerId,
    Map<String, dynamic> consentData,
  ) async {
    final response = await _dio.post(
      '/signers/$signerId/consent',
      data: consentData,
    );
    return response.data;
  }

  // Sign methods
  Future<List<Map<String, dynamic>>> listSigns({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/signs/',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getSigns({
    int skip = 0,
    int limit = 100,
  }) async {
    return listSigns(skip: skip, limit: limit);
  }

  Future<Map<String, dynamic>> getSign(String signId) async {
    final response = await _dio.get('/signs/$signId');
    return response.data;
  }

  Future<Map<String, dynamic>> getSignByCode(String signCode) async {
    final response = await _dio.get('/signs/code/$signCode');
    return response.data;
  }

  Future<Map<String, dynamic>> createSign(Map<String, dynamic> signData) async {
    final response = await _dio.post('/signs/', data: signData);
    return response.data;
  }

  // Session methods
  Future<Map<String, dynamic>> createSession(
    Map<String, dynamic> sessionData,
  ) async {
    final response = await _dio.post('/sessions/', data: sessionData);
    return response.data;
  }

  Future<List<Map<String, dynamic>>> listSessions({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/sessions/',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getSessions({
    int skip = 0,
    int limit = 100,
  }) async {
    return listSessions(skip: skip, limit: limit);
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response = await _dio.get('/sessions/$sessionId');
    return response.data;
  }

  Future<Map<String, dynamic>> updateSession(
    String sessionId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await _dio.patch('/sessions/$sessionId', data: updateData);
    return response.data;
  }

  Future<Map<String, dynamic>> startSession(String sessionId) async {
    final response = await _dio.post('/sessions/$sessionId/start');
    return response.data;
  }

  Future<Map<String, dynamic>> completeSession(String sessionId) async {
    final response = await _dio.post('/sessions/$sessionId/complete');
    return response.data;
  }

  Future<Map<String, dynamic>> cancelSession(String sessionId) async {
    final response = await _dio.post('/sessions/$sessionId/cancel');
    return response.data;
  }

  // Recording methods
  Future<List<Map<String, dynamic>>> listRecordings({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/recordings/',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> getRecording(String recordingId) async {
    final response = await _dio.get('/recordings/$recordingId');
    return response.data;
  }

  Future<List<Map<String, dynamic>>> listOrientationFrames(
    String recordingId, {
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/recordings/$recordingId/frames',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> createRecording(
    Map<String, dynamic> recordingData,
  ) async {
    final response = await _dio.post('/recordings/', data: recordingData);
    notifyRecordingsChanged();
    return response.data;
  }

  Future<Map<String, dynamic>> updateRecording(
    String recordingId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await _dio.patch(
      '/recordings/$recordingId',
      data: updateData,
    );
    notifyRecordingsChanged();
    return response.data;
  }

  Future<void> deleteRecording(String recordingId) async {
    await _dio.delete('/recordings/$recordingId');
    notifyRecordingsChanged();
  }

  Future<List<Map<String, dynamic>>> listRecentActivity({
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/activity/',
      queryParameters: {'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> uploadRecordingVideo(
    String recordingId, {
    Uint8List? videoBytes,
    String? localPath,
    required int fileSize,
    required String fileName,
    required String mimeType,
  }) async {
    if (fileSize <= 0) throw StateError('The video file is empty.');
    final reservation = await _dio.post(
      '/recordings/$recordingId/upload-url',
      data: {
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': fileSize,
      },
    );
    final uploadUrl = reservation.data['upload_url']?.toString();
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw StateError('The server did not return an R2 upload URL.');
    }
    // Browser PUTs to R2 require a bucket CORS preflight. Use the authenticated
    // API proxy first on web so a missing bucket CORS rule cannot make a saved
    // recording look like a failure. Keep direct signed PUT as a fallback.
    // Native clients stream directly to R2 with a separate HTTP client so the
    // API Authorization header stays private.
    var stage = kIsWeb && videoBytes != null
        ? 'Uploading video through the SignBridge server'
        : 'Uploading video to Cloudflare R2';
    try {
      if (kIsWeb && videoBytes != null) {
        try {
          await _uploadVideoThroughApi(
            recordingId,
            videoBytes,
            fileName,
            mimeType,
          );
        } catch (_) {
          // A bucket with working CORS can still accept the signed browser PUT
          // if the API proxy is unavailable or the upload exceeds its limits.
          stage = 'Uploading video to Cloudflare R2';
          await putVideoObject(
            uploadUrl,
            mimeType: mimeType,
            contentLength: fileSize,
            bytes: videoBytes,
          );
        }
      } else {
        await putVideoObject(
          uploadUrl,
          mimeType: mimeType,
          contentLength: fileSize,
          bytes: videoBytes,
          filePath: localPath,
        );
      }
      stage = 'Finalizing the uploaded video';
      final response = await _dio.post(
        '/recordings/$recordingId/complete-upload',
      );
      notifyRecordingsChanged();
      return Map<String, dynamic>.from(response.data);
    } catch (error) {
      Object failureError = error;
      final failure = _describeVideoUploadFailure(failureError, stage);
      try {
        final latest = await getRecording(recordingId);
        if (latest['cloud_storage_status'] == 'uploaded') {
          notifyRecordingsChanged();
          return latest;
        }
        await _dio.post(
          '/recordings/$recordingId/upload-failed',
          data: {
            'error': failure.substring(
              0,
              failure.length > 500 ? 500 : failure.length,
            ),
          },
        );
      } catch (_) {
        // A later retry can re-reserve even if this cleanup request fails.
      }
      throw StateError('$failure Retry from the review screen.');
    }
  }

  Future<void> _uploadVideoThroughApi(
    String recordingId,
    Uint8List videoBytes,
    String fileName,
    String mimeType,
  ) async {
    await _dio.post<void>(
      '/recordings/$recordingId/upload-proxy',
      data: FormData.fromMap({
        'mime_type': mimeType,
        'video': MultipartFile.fromBytes(videoBytes, filename: fileName),
      }),
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
  }

  Future<String> getRecordingVideoUrl(String recordingId) async {
    final recording = await getRecording(recordingId);
    final fileUrl = recording['file_url']?.toString();
    if (fileUrl == null || fileUrl.isEmpty) {
      throw StateError('This recording does not have an uploaded video file.');
    }
    final objectKey =
        recording['storage_path']?.toString() ??
        recording['cloud_object_key']?.toString();
    if (objectKey != null && objectKey.isNotEmpty) {
      final response = await _dio.get('/recordings/$recordingId/download-url');
      final url = response.data['url']?.toString();
      if (url == null || url.isEmpty) {
        throw StateError('The server did not return a temporary video URL.');
      }
      return url;
    }
    return resolveFileUrl(fileUrl);
  }

  // Dataset version methods
  Future<Map<String, dynamic>> createDatasetVersion(
    Map<String, dynamic> datasetData,
  ) async {
    final response = await _dio.post('/datasets/', data: datasetData);
    return response.data;
  }

  Future<List<Map<String, dynamic>>> listDatasetVersions({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/datasets/',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> getDatasetVersion(String datasetId) async {
    final response = await _dio.get('/datasets/$datasetId');
    return response.data;
  }

  Future<Map<String, dynamic>> getDatasetByVersionNumber(
    String versionNumber,
  ) async {
    final response = await _dio.get('/datasets/version/$versionNumber');
    return response.data;
  }

  Future<void> downloadDataset(String datasetId, {String? fileName}) async {
    final response = await _dio.get(
      '/datasets/$datasetId/download',
      // The server prepares the ZIP before sending response headers, then
      // streams the archive. Both phases can exceed the normal API timeout.
      options: Options(
        responseType: ResponseType.bytes,
        connectTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    // Save the file (for web, trigger download)
    if (kIsWeb) {
      browser.downloadBytes(
        Uint8List.fromList(List<int>.from(response.data)),
        '${fileName ?? 'dataset'}.zip',
        'application/zip',
      );
    }
  }

  Future<void> downloadAllRecordings() async {
    final response = await _dio.get(
      '/datasets/recordings/download-all',
      options: Options(
        responseType: ResponseType.bytes,
        connectTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    // Save the file (for web, trigger download)
    if (kIsWeb) {
      browser.downloadBytes(
        Uint8List.fromList(List<int>.from(response.data)),
        'all_recordings.zip',
        'application/zip',
      );
    }
  }
}

// Riverpod provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
