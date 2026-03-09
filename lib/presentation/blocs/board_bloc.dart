import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/board_usecases.dart';
import 'board_event.dart';
import 'board_state.dart';

class BoardBloc extends Bloc<BoardEvent, BoardState> {
  final GetBoards getBoards;
  final AddBoard addBoard;
  final UpdateBoard updateBoard;
  final DeleteBoard deleteBoard;

  BoardBloc({
    required this.getBoards,
    required this.addBoard,
    required this.updateBoard,
    required this.deleteBoard,
  }) : super(BoardInitial()) {
    on<LoadBoards>(_onLoadBoards);
    on<AddBoardEvent>(_onAddBoard);
    on<UpdateBoardEvent>(_onUpdateBoard);
    on<DeleteBoardEvent>(_onDeleteBoard);
  }

  Future<void> _onLoadBoards(LoadBoards event, Emitter<BoardState> emit) async {
    final currentState = state;
    if (currentState is! BoardLoaded) {
      emit(BoardLoading());
    }
    try {
      final boards = await getBoards.call();
      emit(BoardLoaded(boards));
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }

  Future<void> _onAddBoard(
    AddBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    try {
      await addBoard.call(event.board);
      add(LoadBoards());
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }

  Future<void> _onUpdateBoard(
    UpdateBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    try {
      await updateBoard.call(event.board);
      add(LoadBoards());
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }

  Future<void> _onDeleteBoard(
    DeleteBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    try {
      await deleteBoard.call(event.id);
      add(LoadBoards());
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }
}
