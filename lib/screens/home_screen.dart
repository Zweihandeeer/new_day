import 'package:flutter/material.dart';
import 'package:flutter_gemini/providers/chat_provider.dart';
import 'package:flutter_gemini/screens/chat_screen.dart';
import 'package:flutter_gemini/screens/chat_history_screen.dart';
import 'package:flutter_gemini/screens/profile_screen.dart';
import 'package:flutter_gemini/screens/upload_pdf_screen.dart';
import 'package:flutter_gemini/screens/pdf_chat_screen.dart'; // 🚨 AÑADIDO PARA CHAT PDF
import 'package:flutter_gemini/screens/metrics_screen.dart'; // 🚨 AÑADIDO PARA MÉTRICAS
import 'package:provider/provider.dart';
import 'package:flutter_gemini/services/metrics_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.database == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: PageView(
            controller: chatProvider.pageController,
            onPageChanged: (index) {
              chatProvider.setCurrentIndex(newIndex: index);
            },
            children: [
              const ChatHistoryScreen(),
              const ChatScreen(),
              const UploadPdfScreen(),
              const PdfChatScreen(),
              MetricsScreen(metricsService: MetricsService(chatProvider.database!)),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: chatProvider.currentIndex,
            onTap: (index) {
              if (index == 5) return;
              chatProvider.setCurrentIndex(newIndex: index);
              chatProvider.pageController.jumpToPage(index);
            },
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            backgroundColor: Theme.of(context).colorScheme.surface,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Historial',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.chat),
                label: 'Chat',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.upload_file),
                label: 'Subir PDF',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.article),
                label: 'Chat PDF',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Métricas',
              ),
              BottomNavigationBarItem(
                icon: PopupMenuButton<int>(
                  icon: const Icon(Icons.menu),
                  onSelected: (value) {
                    if (value == 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<int>(
                      value: 0,
                      child: ListTile(
                        leading: Icon(Icons.person),
                        title: Text('Perfil'),
                      ),
                    ),
                  ],
                ),
                label: 'Más',
              ),
            ],
          ),
        );
      },
    );
  }
}
