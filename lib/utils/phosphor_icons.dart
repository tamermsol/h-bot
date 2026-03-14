import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Phosphor icon mappings per design spec (01-DESIGN-TOKENS.md Section 10)
/// Line weight 1.5px, 24px standard size
/// Replaces Material Icons throughout the app
class HBotIcons {
  HBotIcons._();

  // ─── Navigation ───
  static IconData get home => PhosphorIcons.house();
  static IconData get homeFilled => PhosphorIcons.house(PhosphorIconsStyle.fill);
  static IconData get scenes => PhosphorIcons.sparkle();
  static IconData get scenesFilled => PhosphorIcons.sparkle(PhosphorIconsStyle.fill);
  static IconData get profile => PhosphorIcons.user();
  static IconData get profileFilled => PhosphorIcons.user(PhosphorIconsStyle.fill);

  // ─── Device Types ───
  static IconData get lightbulb => PhosphorIcons.lightbulb();
  static IconData get lightbulbFilled => PhosphorIcons.lightbulb(PhosphorIconsStyle.fill);
  static IconData get thermometer => PhosphorIcons.thermometer();
  static IconData get shutter => PhosphorIcons.squareHalf();
  static IconData get toggleRight => PhosphorIcons.toggleRight();
  static IconData get toggleRightFilled => PhosphorIcons.toggleRight(PhosphorIconsStyle.fill);
  static IconData get lightning => PhosphorIcons.lightning();
  static IconData get deviceUnknown => PhosphorIcons.circuitry();

  // ─── Actions ───
  static IconData get add => PhosphorIcons.plus();
  static IconData get search => PhosphorIcons.magnifyingGlass();
  static IconData get settings => PhosphorIcons.gear();
  static IconData get settingsFilled => PhosphorIcons.gear(PhosphorIconsStyle.fill);
  static IconData get notifications => PhosphorIcons.bell();
  static IconData get notificationsFilled => PhosphorIcons.bell(PhosphorIconsStyle.fill);
  static IconData get edit => PhosphorIcons.pencilSimple();
  static IconData get delete => PhosphorIcons.trash();
  static IconData get share => PhosphorIcons.shareNetwork();
  static IconData get copy => PhosphorIcons.copy();
  static IconData get close => PhosphorIcons.x();
  static IconData get back => PhosphorIcons.arrowLeft();
  static IconData get chevronRight => PhosphorIcons.caretRight();
  static IconData get chevronDown => PhosphorIcons.caretDown();
  static IconData get more => PhosphorIcons.dotsThreeVertical();
  static IconData get tune => PhosphorIcons.sliders();
  static IconData get refresh => PhosphorIcons.arrowClockwise();

  // ─── Status ───
  static IconData get checkCircle => PhosphorIcons.checkCircle();
  static IconData get warningCircle => PhosphorIcons.warningCircle();
  static IconData get info => PhosphorIcons.info();
  static IconData get error => PhosphorIcons.warning();
  static IconData get wifi => PhosphorIcons.wifiHigh();
  static IconData get wifiOff => PhosphorIcons.wifiSlash();

  // ─── Controls ───
  static IconData get play => PhosphorIcons.play();
  static IconData get playFilled => PhosphorIcons.play(PhosphorIconsStyle.fill);
  static IconData get pause => PhosphorIcons.pause();
  static IconData get stop => PhosphorIcons.stop();
  static IconData get arrowUp => PhosphorIcons.arrowUp();
  static IconData get arrowDown => PhosphorIcons.arrowDown();
  static IconData get timer => PhosphorIcons.timer();
  static IconData get timerOff => PhosphorIcons.clockCountdown();
  static IconData get power => PhosphorIcons.power();

  // ─── Profile / Settings ───
  static IconData get room => PhosphorIcons.door();
  static IconData get palette => PhosphorIcons.palette();
  static IconData get help => PhosphorIcons.question();
  static IconData get feedback => PhosphorIcons.chatText();
  static IconData get about => PhosphorIcons.info();
  static IconData get account => PhosphorIcons.userCircle();
  static IconData get signOut => PhosphorIcons.signOut();
  static IconData get camera => PhosphorIcons.camera();
  static IconData get eye => PhosphorIcons.eye();
  static IconData get eyeOff => PhosphorIcons.eyeSlash();
  static IconData get email => PhosphorIcons.envelope();
  static IconData get lock => PhosphorIcons.lock();
  static IconData get devices => PhosphorIcons.devices();
  static IconData get smartToy => PhosphorIcons.robot();
  static IconData get login => PhosphorIcons.signIn();
  static IconData get person => PhosphorIcons.userCircle();
  static IconData get phone => PhosphorIcons.phone();

  // ─── Data / Technical ───
  static IconData get bolt => PhosphorIcons.lightning();
  static IconData get meter => PhosphorIcons.gauge();
  static IconData get network => PhosphorIcons.globe();
  static IconData get lan => PhosphorIcons.graph();
  static IconData get firmware => PhosphorIcons.arrowSquareUp();
  static IconData get memory => PhosphorIcons.cpu();
  static IconData get deviceHub => PhosphorIcons.plugs();
  static IconData get bug => PhosphorIcons.bug();
  static IconData get openInNew => PhosphorIcons.arrowSquareOut();

  // ─── View / Layout ───
  static IconData get gridView => PhosphorIcons.squaresFour();
  static IconData get listView => PhosphorIcons.list();
  static IconData get visibility => PhosphorIcons.eye();
  static IconData get visibilityOff => PhosphorIcons.eyeSlash();
  static IconData get sortAlpha => PhosphorIcons.sortAscending();
  static IconData get category => PhosphorIcons.squaresFour();
  static IconData get accessTime => PhosphorIcons.clock();
  static IconData get check => PhosphorIcons.check();
  static IconData get checkFilled => PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
  static IconData get image => PhosphorIcons.image();
  static IconData get building => PhosphorIcons.buildings();
  static IconData get wifiFind => PhosphorIcons.wifiHigh();
  static IconData get errorOutline => PhosphorIcons.warningCircle();

  // ─── Scene Icons ───
  static IconData get sun => PhosphorIcons.sun();
  static IconData get moon => PhosphorIcons.moon();
  static IconData get shield => PhosphorIcons.shield();
  static IconData get celebration => PhosphorIcons.confetti();
  static IconData get briefcase => PhosphorIcons.briefcase();
  static IconData get barbell => PhosphorIcons.barbell();
  static IconData get coffee => PhosphorIcons.coffee();
  static IconData get music => PhosphorIcons.musicNote();
  static IconData get pawPrint => PhosphorIcons.pawPrint();
  static IconData get flower => PhosphorIcons.flower();
  static IconData get umbrella => PhosphorIcons.umbrella();
  static IconData get leaf => PhosphorIcons.leaf();
  static IconData get fire => PhosphorIcons.fire();
  static IconData get broom => PhosphorIcons.broom();
  static IconData get couch => PhosphorIcons.couch();
  static IconData get graduationCap => PhosphorIcons.graduationCap();
  static IconData get shoppingCart => PhosphorIcons.shoppingCart();
  static IconData get device => PhosphorIcons.circuitry();

  // ─── Room Icons ───
  static IconData get bed => PhosphorIcons.bed();
  static IconData get armchair => PhosphorIcons.armchair();
  static IconData get cookingPot => PhosphorIcons.cookingPot();
  static IconData get forkKnife => PhosphorIcons.forkKnife();
  static IconData get bathtub => PhosphorIcons.bathtub();
  static IconData get shower => PhosphorIcons.shower();
  static IconData get desk => PhosphorIcons.desk();
  static IconData get desktop => PhosphorIcons.desktop();
  static IconData get garage => PhosphorIcons.garage();
  static IconData get car => PhosphorIcons.car();
  static IconData get plant => PhosphorIcons.plant();
  static IconData get tree => PhosphorIcons.tree();
  static IconData get park => PhosphorIcons.park();
  static IconData get swimmingPool => PhosphorIcons.swimmingPool();
  static IconData get gameController => PhosphorIcons.gameController();
  static IconData get television => PhosphorIcons.television();
  static IconData get filmSlate => PhosphorIcons.filmSlate();
  static IconData get books => PhosphorIcons.books();
  static IconData get baby => PhosphorIcons.baby();
  static IconData get puzzle => PhosphorIcons.puzzlePiece();
  static IconData get tShirt => PhosphorIcons.tShirt();
  static IconData get washingMachine => PhosphorIcons.washingMachine();
  static IconData get package => PhosphorIcons.package();
  static IconData get warehouse => PhosphorIcons.warehouse();
  static IconData get stairs => PhosphorIcons.stairs();
  static IconData get doorOpen => PhosphorIcons.door();
  static IconData get usersThree => PhosphorIcons.usersThree();
  static IconData get chevronUp => PhosphorIcons.caretUp();

  /// Get device type icon based on DeviceType
  static IconData deviceTypeIcon(String deviceType) {
    switch (deviceType) {
      case 'relay':
      case 'dimmer':
        return lightbulb;
      case 'sensor':
        return thermometer;
      case 'shutter':
        return shutter;
      default:
        return deviceUnknown;
    }
  }
}

/// Device type visual config matching v0 design spec.
/// Returns {icon, color, bgColor} for each device type.
///   relay:   color=#3B82F6, bg=#EFF6FF
///   dimmer:  color=#F59E0B, bg=#FFFBEB
///   sensor:  color=#10B981, bg=#ECFDF5
///   shutter: color=#8B5CF6, bg=#F5F3FF
class DeviceTypeConfig {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const DeviceTypeConfig({
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

DeviceTypeConfig deviceTypeConfig(String type) {
  switch (type) {
    case 'relay':
      return DeviceTypeConfig(
        icon: HBotIcons.lightbulb,
        color: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
      );
    case 'dimmer':
      return DeviceTypeConfig(
        icon: HBotIcons.lightbulb,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
      );
    case 'sensor':
      return DeviceTypeConfig(
        icon: HBotIcons.thermometer,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
      );
    case 'shutter':
      return DeviceTypeConfig(
        icon: HBotIcons.shutter,
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFF5F3FF),
      );
    default:
      return DeviceTypeConfig(
        icon: HBotIcons.deviceUnknown,
        color: const Color(0xFF6B7280),
        bgColor: const Color(0xFFF5F7FA),
      );
  }
}
