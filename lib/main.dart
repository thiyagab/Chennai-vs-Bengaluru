import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:needforspeed/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if(await FirebaseAnalytics.instance.isSupported()){
    FirebaseAnalytics.instance.logAppOpen();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chennai vs Bengaluru',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Chennai vs Bengaluru'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // GlobalKey textkey = GlobalKey();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.help,
                color: Colors.white,
              ),
              onPressed: () {
                showInfo(context);
              },
            )
          ],
        ),
        body: Center(
            child: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(10),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            fetchAndRenderForCity('chennai'),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('vs'),
            ),
            fetchAndRenderForCity('bengaluru')
          ]),
        ))));
  }

  void showInfo(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              title:
                  Text('Info', style: Theme.of(context).textTheme.titleMedium),
              content: Text(
                '"Chennai vs Bengaluru" is an experimental project to show the real time traffic in these cities.'
                '\nThe average speed is calculated using Google Routes API through traffic heavy routes in these cities and is updated periodically'
                '\n\nThe project is still in beta and needs more research and data for accurate info, if you like to join, write me 99products.in@gmail.com',
                style: Theme.of(context).textTheme.bodyMedium,
              ),actions: [
          TextButton(
          child: const Text('Ok'),
          onPressed: () {
          Navigator.of(context).pop();
          },
          )],);
        });
  }

  Widget fetchAndRenderForCity(String city) {
    Future<QuerySnapshot> cityData = FirebaseFirestore.instance
        .collection('routes')
        .where('city', isEqualTo: city)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();

    return FutureBuilder(
        future: cityData,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            double speed = snapshot.data!.docs.first.get('speed');

            List<DateTime> timestamps = [];
            List<double> speeds = [];
            for (var document in snapshot.data!.docs.reversed) {
              double speed = document.get('speed');
              Timestamp timestamp = document.get('timestamp');
              timestamps.add(timestamp.toDate());
              speeds.add(speed);
            }
            return buildForCity(city, speed, timestamps, speeds);
          } else {
            return const Text('Loading ...');
          }
        });
  }

  Widget buildForCity(String city, double speed, List<DateTime> timestamps,
      List<double> speeds) {
    double chartwidth = (MediaQuery.of(context).size.width/2)-100;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          city.substring(0, 1).toUpperCase() +
              city.substring(1, city.length).toLowerCase(),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(
          height: 50,
        ),
        RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: '$speed',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              TextSpan(
                text: ' km/hr',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(
          height: 50,
        ),
        SizedBox(
            width: chartwidth,
            height: 100,
            child: Padding(
                padding: const EdgeInsets.all(0),
                child: buildChart(timestamps, speeds))),
        const SizedBox(
          height: 30,
        ),
      ],
    );
  }

  Widget bottomNote() {
    return Padding(
        padding: const EdgeInsets.all(20),
        child: RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text:
                    'Note:\nSpeed comparison to Bengaluru is coming soon!!\nI Need info on top traffic routes, \nwrite to ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextSpan(
                  text: '99products.in@gmail.com',
                  style: const TextStyle(color: Colors.blue),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      launchUrlString(
                          'mailto:99products.in@gmail.com?subject=Bengaluru-Routes');
                    }),
            ],
          ),
        ));
  }

  Widget formatHourWidget(DateTime dateTime) {
    String hour = dateTime.hour.toString().padLeft(2, '0');
    // String minute = dateTime.minute.toString().padLeft(2, '0');
    String display = '$hour:00';
    return Text(hour);
  }

  String formatTime(DateTime dateTime) {
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String display = '$hour:$minute';
    return display;
  }

  Widget buildChart(List<DateTime> timestamps, List<double> speeds) {
    List<FlSpot> spots = List.generate(timestamps.length, (index) {
      return FlSpot(index.toDouble(), speeds[index]);
    });

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueAccent,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((barSpot) {
                  final flSpot = barSpot;
                  final timestamp = timestamps[flSpot.x
                      .toInt()]; // Assuming timestamps is your x-axis data
                  return LineTooltipItem(
                    'Time: ${formatTime(timestamp)}\nSpeed: ${flSpot.y}', // Customize as needed
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            )),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: false,
                    getTitlesWidget: (value, metadata) {
                      if (value % 5 == 0 && value > 15) {
                        return Text(value.toString());
                      } else {
                        return Container();
                      }
                    })), // Show y-axis titles
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: false,
              interval: (timestamps.length / 5),
              getTitlesWidget: (value, meta) {
                // Convert the x value to a timestamp and return it as a string
                final timestamp = timestamps[value.toInt()];
                return formatHourWidget(timestamp);
              },
            )),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false))),
        borderData: FlBorderData(
          show: false,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        minX: 0,
        minY: speeds.reduce(min) - 5,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
