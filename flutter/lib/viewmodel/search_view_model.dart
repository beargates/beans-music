import '../model/song.dart';
import '../service/music_repository.dart';

class SearchViewModel {
  final MusicRepository repository;

  SearchViewModel(this.repository);

  Future<List<Song>> search(
    String keyword, {
    SongSource source = SongSource.netease,
  }) async {
    return repository.searchBySource(source, keyword);
  }
}
