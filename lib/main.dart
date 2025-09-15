// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/pin_screen/pin_screen.dart';
import 'screens/pin_screen/pin_view_model.dart';
import 'services/document_service.dart';
import 'services/download_service.dart';
import 'api/api_service.dart';

void main() {
  print("APP_LIFECYCLE: main() function called. Starting app...");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        Provider(create: (_) => DocumentService()),

        // This is the change: We are now ONLY creating the service.
        // We are NOT calling ..startDownloading() here anymore.
        ChangeNotifierProvider(
          create: (context) {
            print(
              "APP_LIFECYCLE: DownloadService provider created (but not started).",
            );
            return DownloadService(
              apiService: context.read<ApiService>(),
              documentService: context.read<DocumentService>(),
            );
          },
        ),
        ChangeNotifierProvider(
          create: (context) =>
              PinViewModel(documentService: context.read<DocumentService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Document Printer',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.grey[100],
        ),
        home: const PinScreen(),
      ),
    );
  }
}
