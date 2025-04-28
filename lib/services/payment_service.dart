import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class PaymentService {
  // Check if a UPI app is installed using a more reliable method
  static Future<bool> isAppInstalled(String packageName) async {
    if (Platform.isAndroid) {
      try {
        // Try to create a URI with the app's package scheme
        final Uri uri = Uri(scheme: 'package', host: packageName);
        bool canLaunch = await canLaunchUrl(uri);
        
        // If that doesn't work, try to create a URI with the market scheme
        if (!canLaunch) {
          final Uri marketUri = Uri(scheme: 'market', host: 'details', queryParameters: {'id': packageName});
          canLaunch = await canLaunchUrl(marketUri);
        }
        
        // If that still doesn't work, try to create a direct intent URI
        if (!canLaunch) {
          final upiUri = Uri.parse('upi://pay');
          return await canLaunchUrl(upiUri);
        }
        
        return canLaunch;
      } catch (e) {
        print('Error checking if app is installed: $e');
        return false;
      }
    }
    return false;
  }

  // Get UPI payment apps installed on the device with improved detection
  static Future<List<UpiApp>> getUpiApps() async {
    List<UpiApp> apps = [];
    
    // Try to detect if any UPI app is installed by checking if the UPI scheme can be launched
    final upiUri = Uri.parse('upi://pay');
    final canLaunchUpi = await canLaunchUrl(upiUri);
    
    if (!canLaunchUpi && Platform.isAndroid) {
      print('UPI scheme is not supported on this device. Will try individual apps.');
    }
    
    // Define common UPI apps
    final commonApps = [
      UpiApp(
        name: 'Google Pay',
        packageName: 'com.google.android.apps.nbu.paisa.user',
        iconData: Icons.account_balance_wallet,
        iconColor: Colors.green,
      ),
      UpiApp(
        name: 'PhonePe',
        packageName: 'com.phonepe.app',
        iconData: Icons.payment,
        iconColor: Colors.indigo,
      ),
      UpiApp(
        name: 'Paytm',
        packageName: 'net.one97.paytm',
        iconData: Icons.payment,
        iconColor: Colors.blue,
      ),
      UpiApp(
        name: 'BHIM',
        packageName: 'in.org.npci.upiapp',
        iconData: Icons.account_balance,
        iconColor: Colors.deepPurple,
      ),
    ];

    // Check which apps are installed with improved detection
    if (Platform.isAndroid) {
      for (var app in commonApps) {
        bool isInstalled = await isAppInstalled(app.packageName);
        print('Checking ${app.name}: ${isInstalled ? "Installed" : "Not installed"}');
        if (isInstalled) {
          apps.add(app);
        }
      }
      
      // If no apps were detected but UPI scheme is supported, add a generic UPI option
      if (apps.isEmpty && canLaunchUpi) {
        apps.add(UpiApp(
          name: 'UPI Payment',
          packageName: '',  // Empty package name will use the default intent chooser
          iconData: Icons.payment,
          iconColor: Colors.purple,
        ));
      }
    }

    return apps;
  }

  // Launch UPI payment app directly without autofilling payment details
  static Future<bool> initiateTransaction({
    required String receiverUpiId,
    required String receiverName,
    required String receiverPhone,
    required double amount,
    required String transactionNote,
    required String packageName,
  }) async {
    print('Attempting to launch UPI app directly: ${packageName.isEmpty ? "Default UPI handler" : packageName}');
    
    // For specific apps, launch directly without payment parameters
    if (packageName.isNotEmpty) {
      try {
        // Create an intent to launch the app directly
        final appIntent = Uri(scheme: 'android-app', host: packageName);
        final canLaunchApp = await canLaunchUrl(appIntent);
        
        print('Can launch app directly ($packageName): $canLaunchApp');
        
        if (canLaunchApp) {
          print('Launching app directly');
          return await launchUrl(appIntent, mode: LaunchMode.externalApplication);
        } else {
          // Alternative approach using market scheme
          final marketUri = Uri(scheme: 'market', host: 'details', queryParameters: {'id': packageName});
          final canLaunchMarket = await canLaunchUrl(marketUri);
          
          if (canLaunchMarket) {
            print('Launching app via market scheme');
            return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          }
          
          print('Cannot launch app directly');
          return false;
        }
      } catch (e) {
        print('Error launching UPI app: $e');
        return false;
      }
    } else {
      // Launch with default UPI scheme without payment parameters
      try {
        // Just launch the UPI scheme without any payment parameters
        final uri = Uri.parse('upi://pay');
        final canLaunch = await canLaunchUrl(uri);
        
        print('Can launch with default UPI scheme: $canLaunch');
        
        if (canLaunch) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('Launch result with default UPI scheme: $launched');
          return launched;
        } else {
          print('Cannot launch with default UPI scheme');
          return false;
        }
      } catch (e) {
        print('Error launching UPI intent: $e');
        return false;
      }
    }
  }

  // Show payment app chooser dialog - directly launch system chooser without autofilling payment details
  static Future<void> showPaymentAppChooser({
    required BuildContext context,
    required String receiverUpiId,
    required String receiverName,
    required String receiverPhone,
    required double amount,
    required String transactionNote,
    required Function(bool) onPaymentComplete,
  }) async {
    try {
      // Get available UPI apps
      final upiApps = await getUpiApps();
      
      if (upiApps.isEmpty) {
        print('No UPI apps found on the device');
        onPaymentComplete(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No UPI payment apps found on your device. Please install a UPI app like Google Pay, PhonePe, or Paytm.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      
      // If there's only one app, launch it directly
      if (upiApps.length == 1) {
        final launched = await initiateTransaction(
          receiverUpiId: receiverUpiId,
          receiverName: receiverName,
          receiverPhone: receiverPhone,
          amount: amount,
          transactionNote: transactionNote,
          packageName: upiApps[0].packageName,
        );
        
        onPaymentComplete(launched);
        if (launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening ${upiApps[0].name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open ${upiApps[0].name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // If multiple apps are available, show a chooser dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Choose Payment App'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: upiApps.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    leading: Icon(upiApps[index].iconData, color: upiApps[index].iconColor),
                    title: Text(upiApps[index].name),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final launched = await initiateTransaction(
                        receiverUpiId: receiverUpiId,
                        receiverName: receiverName,
                        receiverPhone: receiverPhone,
                        amount: amount,
                        transactionNote: transactionNote,
                        packageName: upiApps[index].packageName,
                      );
                      
                      onPaymentComplete(launched);
                      if (launched) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Opening ${upiApps[index].name}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to open ${upiApps[index].name}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onPaymentComplete(false);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error showing payment app chooser: $e');
      onPaymentComplete(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// UPI App model
class UpiApp {
  final String name;
  final String packageName;
  final IconData iconData;
  final Color iconColor;

  UpiApp({
    required this.name,
    required this.packageName,
    required this.iconData,
    required this.iconColor,
  });
}

// This class is no longer needed as we're directly showing the system chooser
// Keeping the UpiApp class for app detection functionality
