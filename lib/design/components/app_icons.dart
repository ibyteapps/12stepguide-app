import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The icons the app uses: Material Symbols Rounded on both platforms (UX_UI_SPEC.md §6).
/// Kept in one place so the same meaning always gets the same glyph.
abstract final class AppIcons {
  // Tabs
  static const IconData steps = Symbols.footprint_rounded;
  static const IconData readings = Symbols.auto_stories_rounded;
  static const IconData bigBook = Symbols.menu_book_rounded;
  static const IconData audio = Symbols.headphones_rounded;

  // Drawer
  static const IconData menu = Symbols.menu_rounded;
  static const IconData premium = Symbols.workspace_premium_rounded;
  static const IconData reminders = Symbols.notifications_rounded;
  static const IconData appearance = Symbols.contrast_rounded;
  static const IconData downloads = Symbols.download_for_offline_rounded;
  static const IconData contact = Symbols.mail_rounded;
  static const IconData rate = Symbols.star_rounded;
  static const IconData share = Symbols.share_rounded;
  static const IconData facebook = Symbols.thumb_up_rounded;
  static const IconData otherApps = Symbols.apps_rounded;
  static const IconData privacyChoices = Symbols.privacy_tip_rounded;
  static const IconData privacyPolicy = Symbols.policy_rounded;
  static const IconData terms = Symbols.gavel_rounded;
  static const IconData about = Symbols.info_rounded;

  // Content
  static const IconData intro = Symbols.flag_rounded;
  static const IconData conclusion = Symbols.sports_score_rounded;
  static const IconData prayer = Symbols.self_improvement_rounded;
  static const IconData reading = Symbols.local_library_rounded;
  static const IconData tip = Symbols.lightbulb_rounded;
  static const IconData dailyReflections = Symbols.wb_sunny_rounded;
  static const IconData calendar = Symbols.calendar_month_rounded;
  static const IconData celebrate = Symbols.celebration_rounded;
  static const IconData quote = Symbols.format_quote_rounded;
  static const IconData textSize = Symbols.text_fields_rounded;
  static const IconData bookmark = Symbols.bookmark_rounded;

  // Audio
  static const IconData play = Symbols.play_arrow_rounded;
  static const IconData pause = Symbols.pause_rounded;
  static const IconData next = Symbols.skip_next_rounded;
  static const IconData previous = Symbols.skip_previous_rounded;
  static const IconData back10 = Symbols.replay_10_rounded;
  static const IconData forward10 = Symbols.forward_10_rounded;
  static const IconData playAll = Symbols.playlist_play_rounded;
  static const IconData download = Symbols.download_rounded;
  static const IconData downloaded = Symbols.download_done_rounded;
  static const IconData equaliser = Symbols.graphic_eq_rounded;
  static const IconData stop = Symbols.stop_rounded;
  static const IconData album = Symbols.album_rounded;

  // General
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData chevron = Symbols.chevron_right_rounded;
  static const IconData expand = Symbols.keyboard_arrow_down_rounded;
  static const IconData openExternal = Symbols.open_in_new_rounded;
  static const IconData offline = Symbols.wifi_off_rounded;
  static const IconData error = Symbols.cloud_off_rounded;
  static const IconData retry = Symbols.refresh_rounded;
  static const IconData check = Symbols.check_circle_rounded;
  static const IconData lock = Symbols.lock_rounded;
  static const IconData delete = Symbols.delete_rounded;
  static const IconData storage = Symbols.storage_rounded;
  static const IconData restore = Symbols.restore_rounded;
  static const IconData copy = Symbols.content_copy_rounded;
  static const IconData verified = Symbols.verified_rounded;
  static const IconData support = Symbols.volunteer_activism_rounded;
  static const IconData light = Symbols.light_mode_rounded;
  static const IconData dark = Symbols.dark_mode_rounded;
  static const IconData system = Symbols.brightness_auto_rounded;
  static const IconData pending = Symbols.hourglass_top_rounded;
  static const IconData noAds = Symbols.block_rounded;
}
