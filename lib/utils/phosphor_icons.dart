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
