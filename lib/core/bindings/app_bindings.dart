import 'package:get/get.dart';

import 'package:stephen_farmer/feature/auth/presentation/controller/login_controller.dart';

import '../../feature/auth/data/repo/auth_repo_impl.dart';
import '../../feature/auth/domain/repo/auth_repo.dart';
import '../network/api_service/api_client.dart';
import '../network/api_service/api_endpoints.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    final apiClient = ApiClient(baseUrl);

    Get.put<ApiClient>(apiClient, permanent: true);

    Get.put<AuthRepository>(
      AuthRepositoryImpl(Get.find<ApiClient>()),
      permanent: true,
    );

    Get.put<LoginController>(LoginController(Get.find<AuthRepository>()));
  }
}
