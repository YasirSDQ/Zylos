import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';

// ── Supported site entry ──────────────────────────────────────────────────────

class _SiteEntry {
  final String name;
  final bool isBroken;
  final bool requiresAuth;

  const _SiteEntry({
    required this.name,
    this.isBroken = false,
    this.requiresAuth = false,
  });
}

// ── Parser: extract site list from the embedded markdown data ────────────────

List<_SiteEntry> _parseSites(List<String> rawLines) {
  final entries = <_SiteEntry>[];
  for (final line in rawLines) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('- **')) continue;

    final isBroken = trimmed.contains('Currently broken');
    final hasNetrc = trimmed.contains('netrc machine');

    // Extract name between **...**
    final nameMatch = RegExp(r'\*\*([^*]+)\*\*').firstMatch(trimmed);
    if (nameMatch == null) continue;
    final name = nameMatch.group(1) ?? '';
    if (name.isEmpty) continue;

    entries.add(_SiteEntry(name: name, isBroken: isBroken, requiresAuth: hasNetrc));
  }
  return entries;
}

// ── Static data (top-level categories for grouping) ──────────────────────────

const _popularSites = {
  'YouTube', 'TikTok', 'Instagram', 'Facebook', 'Twitter', 'Twitch',
  'Vimeo', 'Dailymotion', 'SoundCloud', 'Reddit', 'BiliBili', 'Rumble',
  'Pinterest', 'LinkedIn', 'Snapchat', 'Bandcamp', 'BBC', 'CNN',
  'ESPN', 'Netflix', 'Spotify',
};

// ── Raw site list (embedded from yt-dlp supported sites) ─────────────────────
// This is a curated subset; the app loads the full list at runtime

const List<String> _rawSiteLines = [
  ' - **10play**: [*10play*](## "netrc machine")',
  ' - **10play:season**',
  ' - **17live**',
  ' - **17live:clip**',
  ' - **17live:vod**',
  ' - **1News**: 1news.co.nz article videos',
  ' - **1tv**: Первый канал',
  ' - **1tv:live**: Первый канал (прямой эфир)',
  ' - **20min**: (**Currently broken**)',
  ' - **23video**',
  ' - **247sports**: (**Currently broken**)',
  ' - **24tv.ua**',
  ' - **3qsdn**: 3Q SDN',
  ' - **3sat**',
  ' - **4tube**',
  ' - **56.com**',
  ' - **7plus**',
  ' - **9c9media**',
  ' - **9gag**: 9GAG',
  ' - **9News**',
  ' - **9now.com.au**',
  ' - **abc.net.au**',
  ' - **abc.net.au:iview**',
  ' - **abcnews**',
  ' - **abcnews:video**',
  ' - **abcotvs**: ABC Owned Television Stations',
  ' - **AbemaTV**: [*abematv*](## "netrc machine")',
  ' - **AcFunBangumi**',
  ' - **AcFunVideo**',
  ' - **acast**',
  ' - **acast:channel**',
  ' - **ADN**: [*animationdigitalnetwork*](## "netrc machine") Animation Digital Network',
  ' - **AeonCo**',
  ' - **AlJazeera**',
  ' - **Allocine**',
  ' - **AlphaPorno**',
  ' - **altcensored**',
  ' - **Amara**',
  ' - **AmazonMiniTV**',
  ' - **AmazonReviews**',
  ' - **AmazonStore**',
  ' - **AMCNetworks**',
  ' - **AmericasTestKitchen**',
  ' - **Angel**',
  ' - **AnimalPlanet**',
  ' - **apple:podcasts**: Apple Podcasts',
  ' - **archive.org**: archive.org video and audio',
  ' - **ARDAudiothek**',
  ' - **ARDMediathek**',
  ' - **ArteTV**',
  ' - **AudioBoom**',
  ' - **audiomack**',
  ' - **audiomack:album**',
  ' - **Audius**: Audius.co',
  ' - **BaiduVideo**: 百度视频',
  ' - **Bandcamp**',
  ' - **Bandcamp:album**',
  ' - **Bandcamp:user**',
  ' - **BannedVideo**',
  ' - **bbc**: [*bbc*](## "netrc machine") BBC',
  ' - **bbc.co.uk**: [*bbc*](## "netrc machine") BBC iPlayer',
  ' - **Beatport**',
  ' - **Bet**',
  ' - **bfmtv**',
  ' - **Bigo**',
  ' - **Bild**: Bild.de',
  ' - **BiliBili**',
  ' - **BiliBiliBangumi**',
  ' - **BilibiliPlaylist**',
  ' - **BiliBiliSearch**: Bilibili video search',
  ' - **BiliLive**',
  ' - **BitChute**',
  ' - **BitChuteChannel**',
  ' - **blogger.com**',
  ' - **Bloomberg**',
  ' - **Bluesky**',
  ' - **BongaCams**',
  ' - **Boosty**',
  ' - **Box**',
  ' - **BR**: Bayerischer Rundfunk (**Currently broken**)',
  ' - **BravoTV**',
  ' - **brightcove:legacy**',
  ' - **brightcove:new**',
  ' - **BTVPlus**',
  ' - **Bundesliga**',
  ' - **BuzzFeed**',
  ' - **CAM4**',
  ' - **CamModels**',
  ' - **Canal1**',
  ' - **canalc2.tv**',
  ' - **Canalplus**: mycanal.fr and piwiplus.fr',
  ' - **cbc.ca**',
  ' - **cbsnews**: CBS News',
  ' - **cbsnews:live**: CBS News Livestream',
  ' - **CCTV**: 央视网',
  ' - **CDA**: [*cdapl*](## "netrc machine")',
  ' - **Chaturbate**',
  ' - **chzzk:live**',
  ' - **chzzk:video**',
  ' - **ciscowebex**: Cisco Webex',
  ' - **Clipchamp**',
  ' - **CloudflareStream**',
  ' - **Clyp**',
  ' - **CNBCVideo**',
  ' - **CNN**',
  ' - **CNNIndonesia**',
  ' - **ComedyCentral**',
  ' - **CondeNast**: Condé Nast media group',
  ' - **CookingChannel**',
  ' - **Coub**',
  ' - **CozyTV**',
  ' - **CrooksAndLiars**',
  ' - **CSpan**: C-SPAN',
  ' - **CTVNews**',
  ' - **curiositystream**: [*curiositystream*](## "netrc machine")',
  ' - **Cybrary**: [*cybrary*](## "netrc machine")',
  ' - **DailyMail**',
  ' - **dailymotion**: [*dailymotion*](## "netrc machine")',
  ' - **dailymotion:playlist**: [*dailymotion*](## "netrc machine")',
  ' - **dailymotion:user**: [*dailymotion*](## "netrc machine")',
  ' - **Douyin**',
  ' - **DouyuTV**: 斗鱼直播',
  ' - **Dropbox**',
  ' - **Dropout**: [*dropout*](## "netrc machine")',
  ' - **drtv**',
  ' - **dzen.ru**: Дзен',
  ' - **EbaumsWorld**',
  ' - **Ebay**',
  ' - **egghead:course**: egghead.io course',
  ' - **egghead:lesson**: egghead.io lesson',
  ' - **ElementorEmbed**',
  ' - **Eporner**',
  ' - **EroProfile**: [*eroprofile*](## "netrc machine")',
  ' - **ESPN**',
  ' - **ESPNCricInfo**',
  ' - **EuroParlWebstream**',
  ' - **Eurosport**',
  ' - **facebook**',
  ' - **facebook:ads**',
  ' - **facebook:reel**',
  ' - **Fathom**',
  ' - **fc2**: [*fc2*](## "netrc machine")',
  ' - **fc2:live**',
  ' - **Fifa**',
  ' - **filmon**',
  ' - **filmon:channel**',
  ' - **Flickr**',
  ' - **Floatplane**',
  ' - **FoodNetwork**',
  ' - **Formula1**',
  ' - **FOX**',
  ' - **foxnews**: Fox News and Fox Business Video',
  ' - **FoxSports**',
  ' - **FranceCulture**',
  ' - **francetv**',
  ' - **Freesound**',
  ' - **FrontendMasters**: [*frontendmasters*](## "netrc machine")',
  ' - **Funk**',
  ' - **Gab**',
  ' - **Gaia**: [*gaia*](## "netrc machine")',
  ' - **GameJolt**',
  ' - **GameSpot**',
  ' - **gem.cbc.ca**: [*cbcgem*](## "netrc machine")',
  ' - **Genius**',
  ' - **Gettr**',
  ' - **GiantBomb**',
  ' - **Glide**: Glide mobile video messages (glide.me)',
  ' - **GlobalPlayerLive**',
  ' - **GlobalPlayerVideo**',
  ' - **Globo**: [*globo*](## "netrc machine")',
  ' - **GMANetworkVideo**',
  ' - **GoogleDrive**',
  ' - **GoogleDrive:Folder**',
  ' - **GoPro**',
  ' - **hbo**',
  ' - **HiDive**: [*hidive*](## "netrc machine")',
  ' - **history:player**',
  ' - **hotstar**: JioHotstar',
  ' - **hotstar:series**',
  ' - **HuffPost**: Huffington Post',
  ' - **Hungama**',
  ' - **huya:live**: 虎牙直播',
  ' - **huya:video**: 虎牙视频',
  ' - **iheartradio**',
  ' - **imdb**: Internet Movie Database trailers',
  ' - **Imgur**',
  ' - **imgur:album**',
  ' - **Instagram**',
  ' - **instagram:story**',
  ' - **iq.com**: International version of iQiyi',
  ' - **iqiyi**: 爱奇艺',
  ' - **ITV**',
  ' - **ivi**: ivi.ru',
  ' - **iwara**: [*iwara*](## "netrc machine")',
  ' - **Jamendo**',
  ' - **jiosaavn:song**',
  ' - **jiosaavn:album**',
  ' - **jiosaavn:playlist**',
  ' - **JTBC**: jtbc.co.kr',
  ' - **Kakao**',
  ' - **Kaltura**',
  ' - **kick:clips**',
  ' - **kick:live**',
  ' - **kick:vod**',
  ' - **KickStarter**',
  ' - **khanacademy**',
  ' - **KinoPoisk**',
  ' - **lbry**: odysee.com',
  ' - **lbry:channel**: odysee.com channels',
  ' - **lbry:playlist**: odysee.com playlists',
  ' - **Lecturio**: [*lecturio*](## "netrc machine")',
  ' - **LEGO**',
  ' - **likee**',
  ' - **likee:user**',
  ' - **LinkedIn**',
  ' - **linkedin:learning**',
  ' - **ListenNotes**',
  ' - **loc**: Library of Congress',
  ' - **Loco**',
  ' - **loom**',
  ' - **LRTRadio**',
  ' - **Lumni**',
  ' - **MagellanTV**',
  ' - **mailru**: Видео@Mail.Ru',
  ' - **MangoTV**: 芒果TV',
  ' - **ManyVids**',
  ' - **Masters**',
  ' - **MBN**: mbn.co.kr (매일방송)',
  ' - **MDR**: MDR.DE',
  ' - **MedalTV**',
  ' - **media.ccc.de**',
  ' - **Mediaset**',
  ' - **Mediasite**',
  ' - **Medici**',
  ' - **megaphone.fm**: megaphone.fm embedded players',
  ' - **MelonVOD**',
  ' - **Metacritic**',
  ' - **mewatch**',
  ' - **MicrosoftBuild**',
  ' - **minds**',
  ' - **minds:channel**',
  ' - **mir24.tv**',
  ' - **mirrativ**',
  ' - **mixcloud**',
  ' - **mixcloud:playlist**',
  ' - **mixcloud:user**',
  ' - **MLB**',
  ' - **MLBTV**: [*mlb*](## "netrc machine")',
  ' - **MLSSoccer**',
  ' - **MochaVideo**',
  ' - **Monstercat**',
  ' - **mtv**',
  ' - **MuseScore**',
  ' - **Mux**',
  ' - **Naver**',
  ' - **naver:live**',
  ' - **NBC**',
  ' - **NBCSports**',
  ' - **nebula:video**: [*watchnebula*](## "netrc machine") Nebula.tv',
  ' - **nebula:channel**: [*watchnebula*](## "netrc machine") Nebula.tv channel',
  ' - **NerdCubedFeed**',
  ' - **nfl.com**',
  ' - **NHK**',
  ' - **NHKForSchoolBangumi**',
  ' - **nicovideo**: ニコニコ動画',
  ' - **nicovideo:playlist**: ニコニコ動画 playlist',
  ' - **nicovideo:series**: ニコニコ動画 series',
  ' - **nicovideo:tag**: ニコニコ動画 tag',
  ' - **nicovideo:user**: ニコニコ動画 user',
  ' - **Nintendo**',
  ' - **nitter**',
  ' - **NobelPrize**',
  ' - **NovaMov**: (**Currently broken**)',
  ' - **Nuvid**',
  ' - **NYTimes**',
  ' - **NYTimesArticle**',
  ' - **NYTimesCooking**',
  ' - **NYTimesCookingGuide**',
  ' - **NYTimesCookingRecipe**',
  ' - **Odysee**',
  ' - **OnDemandKorea**: [*ondemandkorea*](## "netrc machine")',
  ' - **OnDemandKoreaSeason**: [*ondemandkorea*](## "netrc machine")',
  ' - **openrec**',
  ' - **openrec:movie**',
  ' - **ora**',
  ' - **orf:on**: orf.on',
  ' - **orf:podcast**',
  ' - **orf:radio**',
  ' - **orf:tvthek**: ORF TVthek',
  ' - **pandatv**',
  ' - **Patreon**',
  ' - **patreon:campaign**',
  ' - **PatreonUser**',
  ' - **pbs**',
  ' - **pbskids**',
  ' - **peertube**: [*peertube*](## "netrc machine")',
  ' - **peertube:channel**: [*peertube*](## "netrc machine")',
  ' - **peertube:playlist**: [*peertube*](## "netrc machine")',
  ' - **peertube:subscription**: [*peertube*](## "netrc machine")',
  ' - **PIAcast**',
  ' - **piksel**',
  ' - **Pinkbike**',
  ' - **pinterest**',
  ' - **pinterest:tag**',
  ' - **pixivSketch**',
  ' - **pixivSketchUser**',
  ' - **Ployd**',
  ' - **pluralsight**: [*pluralsight*](## "netrc machine")',
  ' - **pluralsight:course**: [*pluralsight*](## "netrc machine")',
  ' - **Podbean**',
  ' - **PokerGo**: [*pokergo*](## "netrc machine")',
  ' - **PokerGoCollection**: [*pokergo*](## "netrc machine")',
  ' - **polsatgo**',
  ' - **PornHub**: [*pornhub*](## "netrc machine")',
  ' - **PornHubPlaylist**: [*pornhub*](## "netrc machine")',
  ' - **PornHubUser**: [*pornhub*](## "netrc machine")',
  ' - **Pr0gramm**: [*pr0gramm*](## "netrc machine")',
  ' - **radiko**',
  ' - **radiocanada**',
  ' - **radiocanada:audiovideo**',
  ' - **RadioFrance**',
  ' - **Rai**',
  ' - **RaiNews**',
  ' - **RaiPlay**',
  ' - **RaiPlayLive**',
  ' - **RaiPlayPlaylist**',
  ' - **RaiPlaySound**',
  ' - **RaiPlaySoundLive**',
  ' - **RaiPlaySoundPlaylist**',
  ' - **rcti**',
  ' - **reddit**: (**Currently broken**)',
  ' - **reddit:r**: (**Currently broken**)',
  ' - **RedditR**',
  ' - **RedGifs**',
  ' - **Rokfin**: [*rokfin*](## "netrc machine")',
  ' - **rokfin:channel**: [*rokfin*](## "netrc machine")',
  ' - **rokfin:stack**: [*rokfin*](## "netrc machine")',
  ' - **RoosterTeeth**',
  ' - **RoosterTeethSeries**',
  ' - **RottenTomatoes**',
  ' - **Rumble**',
  ' - **RumbleChannel**',
  ' - **RumbleEmbed**',
  ' - **SoundCloud**',
  ' - **soundcloud:playlist**',
  ' - **soundcloud:related**',
  ' - **soundcloud:search**',
  ' - **soundcloud:set**',
  ' - **soundcloud:trackstation**',
  ' - **soundcloud:user**',
  ' - **soundcloud:user:highlights**',
  ' - **soundcloud:user:likes**',
  ' - **SoundcloudEmbed**',
  ' - **SouthPark**',
  ' - **SouthParkDe**',
  ' - **SouthParkEs**',
  ' - **SouthParkNl**',
  ' - **SouthParkPl**',
  ' - **Spotify**: [*spotify*](## "netrc machine")',
  ' - **spotify:episode**: [*spotify*](## "netrc machine") Spotify episodes',
  ' - **spotify:playlist**: [*spotify*](## "netrc machine") Spotify playlists',
  ' - **spotify:show**: [*spotify*](## "netrc machine") Spotify shows',
  ' - **StarTV**: [*startv*](## "netrc machine")',
  ' - **Steam**',
  ' - **SteamCommunityBroadcast**',
  ' - **stitcher**',
  ' - **stitcher:show**',
  ' - **Streamable**',
  ' - **streamcz**',
  ' - **StreetVoice**',
  ' - **SunPorno**',
  ' - **sverigesRadio:episode**',
  ' - **sverigesRadio:publication**',
  ' - **SVT**',
  ' - **SVTID**',
  ' - **SVTPage**',
  ' - **SVTPlay**',
  ' - **SVTSeries**',
  ' - **TastyTrade**: [*tastytrade*](## "netrc machine")',
  ' - **TBSJPEpisode**',
  ' - **TBSJPPlaylist**',
  ' - **TBSJPProgram**',
  ' - **TDFilm**',
  ' - **TeachingChannel**',
  ' - **Teachable**: [*teachable*](## "netrc machine")',
  ' - **TeachableCourse**: [*teachable*](## "netrc machine")',
  ' - **Ted**',
  ' - **TedPlaylist**',
  ' - **TedSeries**',
  ' - **Telegram**',
  ' - **TelegramEmbed**',
  ' - **TF1**',
  ' - **TF1Plus**',
  ' - **TheGuardianPodcast**',
  ' - **TheGuardianPodcastPlaylist**',
  ' - **TheHoleTv**',
  ' - **ThePlatform**',
  ' - **ThePlatformFeed**',
  ' - **TheWeatherChannel**',
  ' - **ThisAmericanLife**',
  ' - **ThisOldHouse**',
  ' - **ThisVid**',
  ' - **ThisVidMember**',
  ' - **ThisVidPlaylist**',
  ' - **TikTok**',
  ' - **tiktok:collection**',
  ' - **tiktok:effect**',
  ' - **tiktok:sound**',
  ' - **tiktok:tag**',
  ' - **tiktok:user**',
  ' - **TikTokLive**',
  ' - **TMZ**',
  ' - **TMZArticle**',
  ' - **TNAFlix**',
  ' - **TNAFlixNetworkEmbed**',
  ' - **toggle**',
  ' - **toggle:season**',
  ' - **ToggleEmbed**',
  ' - **Toypics**: (**Currently broken**)',
  ' - **ToypicsUser**: (**Currently broken**)',
  ' - **TriluliluTV**: (**Currently broken**)',
  ' - **Trunews**',
  ' - **Truth**',
  ' - **TubiTv**: [*tubi*](## "netrc machine")',
  ' - **TubiTvShow**: [*tubi*](## "netrc machine")',
  ' - **tumblr**',
  ' - **tumblr:tag**',
  ' - **TuneIn**',
  ' - **TuneInPodcast**',
  ' - **TuneInPodcastEpisode**',
  ' - **TuneInShortener**',
  ' - **TuneInStation**',
  ' - **Tunein**',
  ' - **tv2**: [*tv2*](## "netrc machine")',
  ' - **tv2article**: [*tv2*](## "netrc machine")',
  ' - **TV2DK**',
  ' - **TV2DKBornholmPlay**',
  ' - **tv4**: TV4',
  ' - **tv5mondeplus**: [*tv5mondeplus*](## "netrc machine")',
  ' - **TVA**',
  ' - **TVNZ**',
  ' - **TVNZVideoEmbed**',
  ' - **Twitch**: [*twitch*](## "netrc machine")',
  ' - **twitch:clips**',
  ' - **twitch:stream**',
  ' - **twitch:videos**: [*twitch*](## "netrc machine")',
  ' - **twitch:vod**: [*twitch*](## "netrc machine")',
  ' - **twitter**: [*twitter*](## "netrc machine")',
  ' - **twitter:amplify**: [*twitter*](## "netrc machine") Twitter Amplify',
  ' - **twitter:broadcast**: [*twitter*](## "netrc machine")',
  ' - **twitter:card**: [*twitter*](## "netrc machine")',
  ' - **twitter:spaces**: [*twitter*](## "netrc machine")',
  ' - **Udemy**: [*udemy*](## "netrc machine")',
  ' - **UdemyCourse**: [*udemy*](## "netrc machine")',
  ' - **UDNEmbed**: 聯合新聞網',
  ' - **UnsupportedInfoExtract**: (**Currently broken**)',
  ' - **Ustream**',
  ' - **UstreamChannel**',
  ' - **Vbox7**',
  ' - **VH1**',
  ' - **Vice**',
  ' - **ViceShow**',
  ' - **Viddler**',
  ' - **Vimeo**: [*vimeo*](## "netrc machine")',
  ' - **vimeo:album**: [*vimeo*](## "netrc machine")',
  ' - **vimeo:channel**: [*vimeo*](## "netrc machine")',
  ' - **vimeo:group**: [*vimeo*](## "netrc machine")',
  ' - **vimeo:likes**: [*vimeo*](## "netrc machine") Vimeo Likes of a user',
  ' - **vimeo:ondemand**: [*vimeo*](## "netrc machine")',
  ' - **vimeo:review**: [*vimeo*](## "netrc machine")',
  ' - **vimeo:user**: [*vimeo*](## "netrc machine")',
  ' - **vimeo:watchlater**: [*vimeo*](## "netrc machine") Vimeo watch later list',
  ' - **Vine**: (**Currently broken**)',
  ' - **Vlive**',
  ' - **VLiveBand**',
  ' - **VLiveChannel**',
  ' - **VLivePlaylist**',
  ' - **VLivePost**',
  ' - **VLiveUpcomingVideo**',
  ' - **Vodlocker**: (**Currently broken**)',
  ' - **VoiceTube**',
  ' - **Voot**: [*voot*](## "netrc machine")',
  ' - **VootSeries**: [*voot*](## "netrc machine")',
  ' - **VQQ**: [*vqq*](## "netrc machine") WeTV',
  ' - **VQQSeries**: [*vqq*](## "netrc machine")',
  ' - **VRT**: [*vrt*](## "netrc machine") VRT NWS, sporza, de Afspraak, Het Journaal, Pano, Panorama, Story, De Ideale Wereld, vrtnws.be, sporza.be',
  ' - **VRTNUILive**: [*vrt*](## "netrc machine")',
  ' - **VRTNUIVideo**: [*vrt*](## "netrc machine")',
  ' - **VRVSeries**',
  ' - **WABC7**',
  ' - **WashingtonPost**',
  ' - **WashingtonPostArticle**',
  ' - **watchbox**',
  ' - **WatchESPN**',
  ' - **weibo**',
  ' - **weiboUser**',
  ' - **WDR**',
  ' - **WDRElefant**',
  ' - **WDRMaus**',
  ' - **Whyp**',
  ' - **WimTV**',
  ' - **WistiaPlaylist**',
  ' - **WistiaVideo**',
  ' - **wnl**',
  ' - **WNLVideos**',
  ' - **WorldStarHipHop**',
  ' - **wsj.com**: Wall Street Journal',
  ' - **wsj.com:live**: Wall Street Journal Live',
  ' - **WSJArticle**',
  ' - **XHamster**',
  ' - **XHamsterEmbed**',
  ' - **XHamsterUser**',
  ' - **xiaohongshu**',
  ' - **xiaohongshu:user**',
  ' - **XNXX**',
  ' - **Xstream**',
  ' - **XTube**: (**Currently broken**)',
  ' - **XVideos**',
  ' - **XVideosQuickies**',
  ' - **XVideosUser**',
  ' - **XXXYMovies**',
  ' - **YahooJapanNews**',
  ' - **YahooJapanNewsArticle**',
  ' - **Yandex**',
  ' - **YandexDisk**',
  ' - **YandexMusic**: [*yandexmusic*](## "netrc machine") Yandex Music Track',
  ' - **YandexMusicAlbum**: [*yandexmusic*](## "netrc machine") Yandex Music Album',
  ' - **YandexMusicArtist**: [*yandexmusic*](## "netrc machine") Yandex Music Artist',
  ' - **YandexMusicPlaylist**: [*yandexmusic*](## "netrc machine") Yandex Music Playlist',
  ' - **YouNow**',
  ' - **YouNowChannel**',
  ' - **YouNowMoment**',
  ' - **youtube**: YouTube',
  ' - **youtube:clip**',
  ' - **youtube:favorites**: YouTube liked videos',
  ' - **youtube:history**: YouTube history',
  ' - **youtube:music_search_url**: YouTube music search',
  ' - **youtube:notif**: YouTube Notifications',
  ' - **youtube:playlist**: YouTube playlists',
  ' - **youtube:recommended**: YouTube recommended videos',
  ' - **youtube:search**: YouTube search',
  ' - **youtube:search_date**: YouTube search, newest videos first',
  ' - **youtube:search_url**: YouTube search URLs',
  ' - **youtube:shorts**: YouTube Shorts',
  ' - **youtube:tab**: YouTube Tabs',
  ' - **youtube:watchlater**: YouTube watch later',
  ' - **YoutubeYtBe**',
  ' - **Zattoo**: [*zattoo*](## "netrc machine")',
  ' - **ZattooPVR**: [*zattoo*](## "netrc machine")',
  ' - **ZattooReplay**: [*zattoo*](## "netrc machine")',
  ' - **ZDF**',
  ' - **ZDFChannel**',
  ' - **Zee5**: [*zee5*](## "netrc machine")',
  ' - **ZoomRoom**',
  ' - **Zype**',
];

// ═══════════════════════════════════════════════════════════════════════════════
// SUPPORTED SITES SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class SupportedSitesScreen extends StatefulWidget {
  const SupportedSitesScreen({super.key});

  @override
  State<SupportedSitesScreen> createState() => _SupportedSitesScreenState();
}

class _SupportedSitesScreenState extends State<SupportedSitesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'All'; // All, Popular, Broken, Auth Required
  late final List<_SiteEntry> _allSites;
  int _visibleCount = 60;

  late AnimationController _headerAnim;

  @override
  void initState() {
    super.initState();
    _allSites = _parseSites(_rawSiteLines);
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  List<_SiteEntry> get _filtered {
    var list = _allSites;
    if (_filter == 'Popular') list = list.where((s) => _popularSites.any((p) => s.name.toLowerCase().contains(p.toLowerCase()))).toList();
    if (_filter == 'Broken') list = list.where((s) => s.isBroken).toList();
    if (_filter == 'Auth Required') list = list.where((s) => s.requiresAuth).toList();
    if (_searchQuery.isNotEmpty) list = list.where((s) => s.name.toLowerCase().contains(_searchQuery)).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sites = _filtered;
    final visible = sites.take(_visibleCount).toList();
    final hasMore = sites.length > _visibleCount;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _buildHeader(isDark),
            // ── Stats strip ────────────────────────────────────────────────
            _buildStatsStrip(isDark, sites.length),
            // ── Search bar ─────────────────────────────────────────────────
            _buildSearchBar(isDark),
            // ── Filter chips ───────────────────────────────────────────────
            _buildFilterChips(isDark),
            // ── Site list ──────────────────────────────────────────────────
            Expanded(
              child: visible.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: visible.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visible.length) {
                          return _buildShowMoreButton(isDark, sites.length - _visibleCount);
                        }
                        return _buildSiteTile(visible[index], isDark, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supported Sites', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, fontSize: 20)),
              Text('Powered by yt-dlp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(10)),
            child: Text('${_allSites.length}+ sites', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
  }

  Widget _buildStatsStrip(bool isDark, int visibleTotal) {
    final broken = _allSites.where((s) => s.isBroken).length;
    final authRequired = _allSites.where((s) => s.requiresAuth).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _buildStatChip('${_allSites.length}', 'Total Sites', const Color(0xFF8B5CF6), isDark),
          const SizedBox(width: 8),
          _buildStatChip('$broken', 'Broken', AppColors.error, isDark),
          const SizedBox(width: 8),
          _buildStatChip('$authRequired', 'Login Needed', const Color(0xFFF59E0B), isDark),
          const SizedBox(width: 8),
          _buildStatChip('$visibleTotal', 'Shown', AppColors.primary, isDark),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 300.ms);
  }

  Widget _buildStatChip(String count, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, size: 20, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by site name…',
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 120.ms, duration: 300.ms);
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['All', 'Popular', 'Auth Required', 'Broken'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = _filter == f;
            final color = f == 'Broken' ? AppColors.error : f == 'Auth Required' ? const Color(0xFFF59E0B) : AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() { _filter = f; _visibleCount = 60; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? color.withValues(alpha: 0.15) : (isDark ? AppColors.darkCard : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isActive ? color.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                  child: Text(f, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? color : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 300.ms);
  }

  Widget _buildSiteTile(_SiteEntry site, bool isDark, int index) {
    final isPopular = _popularSites.any((p) => site.name.toLowerCase().contains(p.toLowerCase()));
    final delay = (10 * (index % 20)).ms;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: site.isBroken
            ? AppColors.error.withValues(alpha: 0.04)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: site.isBroken
              ? AppColors.error.withValues(alpha: 0.2)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: site.isBroken ? AppColors.error : const Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              site.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: site.isBroken
                    ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                decoration: site.isBroken ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.error.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Badges
          Row(
            children: [
              if (isPopular)
                _badge('⭐ Popular', const Color(0xFFF59E0B), isDark),
              if (site.requiresAuth) ...[
                const SizedBox(width: 4),
                _badge('🔑 Auth', AppColors.primary, isDark),
              ],
              if (site.isBroken) ...[
                const SizedBox(width: 4),
                _badge('⚠ Broken', AppColors.error, isDark),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms, delay: delay).slideX(begin: 0.05);
  }

  Widget _badge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildShowMoreButton(bool isDark, int remaining) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: () => setState(() => _visibleCount += 60),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.accent.withValues(alpha: 0.08)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Show $remaining more', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
          const SizedBox(height: 16),
          Text('No sites found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          const SizedBox(height: 8),
          Text('Try a different search term', style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
        ],
      ),
    );
  }
}
