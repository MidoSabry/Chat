import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/services/chat_service.dart';
import 'core/services/local_notification_service.dart';
import 'feature/chat/data/remote/chat_remote_data_source.dart';
import 'feature/chat/data/repo/chat_repository.dart';
import 'feature/chat/presentation/cubit/chat_cubit.dart';
import 'feature/chat/presentation/screen/conversation_screen.dart';

 
void main() async{
  // ✅ iOS Simulator: http://localhost:8080
  // ✅ Android Emulator: http://10.0.2.2:8080
  // const baseUrl = 'http://10.0.2.2:8080';


  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.init();


  const port = 8080;
 final baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:$port'   // Android Emulator -> جهازك
      : 'http://localhost:$port'; // iOS Simulator / macOS

  final service = ChatService(baseUrl);
  final remote = ChatRemoteDataSourceImpl(service);
  final repo = ChatRepositoryImpl(remote);

  runApp(MyApp(repo: repo));
}

class MyApp extends StatelessWidget {
  final ChatRepository repo;
  const MyApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocProvider(
        create: (_) => ChatCubit(repo),
        child: const ConversationsScreen(),
      ),
    );
  }
}
