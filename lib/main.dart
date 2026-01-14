import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/chat_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/push_router.dart';
import 'feature/chat/data/remote/chat_remote_data_source.dart';
import 'feature/chat/data/repo/chat_repository.dart';
import 'feature/chat/presentation/cubit/chat_cubit.dart';
import 'feature/chat/presentation/screen/conversation_screen.dart';
import 'feature/chat/presentation/screen/chat_screen.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await LocalNotificationService.init();

 

  const port = 8080;
  final baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:$port'
      : 'http://localhost:$port';

  final service = ChatService(baseUrl);
  final remote = ChatRemoteDataSourceImpl(service);
  final repo = ChatRepositoryImpl(remote);

  final pushRouter = PushRouter(navKey);
  await pushRouter.init();

  runApp(MyApp(repo: repo));
}

class MyApp extends StatelessWidget {
  final ChatRepository repo;
  const MyApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatCubit(repo), // ✅ provider على مستوى التطبيق كله
      child: MaterialApp(
        navigatorKey: navKey,
        routes: {
          '/': (_) => const ConversationsScreen(),

          '/chat': (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as Map;
            final eventId = args['eventId'] as int;
            final myUserId = args['myUserId'] as int;
            final otherUserId = args['otherUserId'] as int;

            return ChatScreen(
              eventId: eventId,
              myUserId: myUserId,
              otherUserId: otherUserId,
            );
          },
        },
      ),
    );
  }
}
