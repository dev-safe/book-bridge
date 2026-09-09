import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:book_bridge/features/chat/domain/repositories/chat_repository.dart';
import 'package:book_bridge/features/chat/presentation/viewmodels/chat_viewmodel.dart';
import 'package:book_bridge/features/chat/domain/entities/conversation.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late ChatViewModel viewModel;
  late MockChatRepository mockRepository;

  setUp(() {
    mockRepository = MockChatRepository();
    viewModel = ChatViewModel(repository: mockRepository);
  });

  group('ChatViewModel - Conversations', () {
    final tConversations = [
      Conversation(
        listingId: '1',
        listingTitle: 'Test Book',
        otherUserId: 'user2',
        otherUserName: 'User Two',
        lastMessage: 'Hello',
        lastMessageAt: DateTime.now(),
        unreadCount: 0,
      ),
    ];

    test(
      'should update conversations and state when loadConversations is successful',
      () async {
        // Arrange
        when(
          () => mockRepository.getConversations(),
        ).thenAnswer((_) async => tConversations);

        // Act
        final future = viewModel.loadConversations();
        expect(viewModel.conversationsState, ChatState.loading);

        await future;

        // Assert
        expect(viewModel.conversations, tConversations);
        expect(viewModel.conversationsState, ChatState.success);
        verify(() => mockRepository.getConversations()).called(1);
      },
    );

    test('should update state to error when loadConversations fails', () async {
      // Arrange
      when(
        () => mockRepository.getConversations(),
      ).thenThrow(Exception('Failed to load'));

      // Act
      await viewModel.loadConversations();

      // Assert
      expect(viewModel.conversationsState, ChatState.error);
      expect(viewModel.conversationsError, contains('Failed to load'));
    });
  });

  group('ChatViewModel - Messaging', () {
    const tListingId = '1';
    const tReceiverId = 'user2';
    const tContent = 'Test message';

    test('should update isSending state during sendMessage', () async {
      // Arrange
      when(
        () => mockRepository.sendMessage(
          listingId: any(named: 'listingId'),
          receiverId: any(named: 'receiverId'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => {});

      // Act
      final future = viewModel.sendMessage(
        listingId: tListingId,
        receiverId: tReceiverId,
        content: tContent,
      );

      expect(viewModel.isSending, true);

      await future;

      // Assert
      expect(viewModel.isSending, false);
      verify(
        () => mockRepository.sendMessage(
          listingId: tListingId,
          receiverId: tReceiverId,
          content: tContent,
        ),
      ).called(1);
    });

    test('should set sendError when sendMessage fails', () async {
      // Arrange
      when(
        () => mockRepository.sendMessage(
          listingId: any(named: 'listingId'),
          receiverId: any(named: 'receiverId'),
          content: any(named: 'content'),
        ),
      ).thenThrow(Exception('Send failed'));

      // Act
      await viewModel.sendMessage(
        listingId: tListingId,
        receiverId: tReceiverId,
        content: tContent,
      );

      // Assert
      expect(viewModel.isSending, false);
      expect(viewModel.sendError, isNotNull);
    });
  });
}
