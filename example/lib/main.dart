// Demo code keeps widget-list helpers and fixed demo strings in one file so
// each sample configuration stays readable.
// ignore_for_file: avoid-returning-widgets, avoid-substring

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabs/tabs.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ExamplePage(),
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage>
    with SingleTickerProviderStateMixin {
  static const _tabBorderRadius = BorderRadius.all(Radius.circular(20.0));
  static const _creditCardBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(20.0),
    topRight: Radius.circular(20.0),
  );
  static const _creditCardTabsExpandedSize = Size(400, 320);

  late final TabController _controller;
  late TextTheme textTheme;
  var _creditCardTabsCollapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = TabController(vsync: this, length: 3);
  }

  @override
  void didChangeDependencies() {
    textTheme = Theme.of(context).textTheme;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Example')),
      body: SingleChildScrollView(
        child: SizedBox(
          height: 2000,
          child: Column(
            children: [
              const Spacer(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: _creditCardTabsExpandedSize.width,
                  maxWidth: _creditCardTabsExpandedSize.width,
                  maxHeight: _creditCardTabsExpandedSize.height,
                ),
                child: _buildCreditCardTabs(),
              ),
              const Spacer(),
              SizedBox(
                height: 320.0,
                width: 400,
                child: Tabs(
                  controller: _controller,
                  borderRadius: BorderRadius.zero,
                  tabBorderRadius: BorderRadius.zero,
                  color: Colors.black,
                  duration: Duration.zero,
                  selectedTextStyle: textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                  unselectedTextStyle: textTheme.bodyMedium?.copyWith(
                    color: Colors.black,
                  ),
                  tabs: _getTabs2(),
                  children: _getChildren2(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    key: const ValueKey('previous-image-tab'),
                    onPressed: () => _moveImageTab(-1),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  IconButton(
                    key: const ValueKey('next-image-tab'),
                    onPressed: () => _moveImageTab(1),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 400,
                height: 400,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Tabs(
                    color: Theme.of(context).colorScheme.secondary,
                    tabEdge: TabEdge.right,
                    childPadding: const EdgeInsets.all(20.0),
                    tabs: _getTabs3(),
                    children: _getChildren3(context),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 400,
                height: 400,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Tabs(
                    color: Theme.of(context).colorScheme.primary,
                    tabEdge: TabEdge.left,
                    tabsStart: 0.1,
                    tabsEnd: 0.6,
                    childPadding: const EdgeInsets.all(20.0),
                    tabs: _getTabs4(),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.0,
                    ),
                    unselectedTextStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 13.0,
                    ),
                    children: _getChildren4(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveImageTab(int delta) {
    final targetIndex = (_controller.index + delta).clamp(
      0,
      _controller.length - 1,
    );
    _controller.animateTo(targetIndex);
  }

  Widget _buildCreditCardTabs() {
    return Tabs(
      collapsed: _creditCardTabsCollapsed,
      onCollapsedChanged: (value) {
        setState(() {
          _creditCardTabsCollapsed = value;
        });
      },
      borderRadius: _creditCardBorderRadius,
      tabBorderRadius: _tabBorderRadius,
      tabEdge: TabEdge.top,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeIn,
      tabLeadingButtons: [
        TabsActionButton(onPressed: () {}, icon: Icons.add_card),
      ],
      tabTrailingButtons: [
        TabsActionButton(
          key: const ValueKey('collapse-credit-card-tabs'),
          action: TabsActionButtonAction.toggleCollapse,
          icon: _creditCardTabsCollapsed
              ? Icons.keyboard_arrow_up
              : Icons.keyboard_arrow_down,
          semanticLabel: _creditCardTabsCollapsed
              ? 'Expand card tabs'
              : 'Collapse card tabs',
        ),
      ],
      colors: const <Color>[
        Color(0xfffa86be),
        Color(0xffa275e3),
        Color(0xff9aebed),
      ],
      unselectedTabColor: const Color.fromARGB(255, 225, 225, 225),
      unselectedTabBorder: const BorderSide(
        color: Color.fromARGB(255, 197, 197, 197),
        width: 1,
      ),
      unselectedTabGap: 4,
      selectedTextStyle: textTheme.bodyMedium?.copyWith(fontSize: 15.0),
      unselectedTextStyle: textTheme.bodyMedium?.copyWith(
        color: Colors.black,
        fontSize: 13.0,
      ),
      tabs: _getTabs1(),
      children: _getChildren1(),
    );
  }

  List<Widget> _getChildren1() {
    final cards = kCreditCards.map(CreditCardData.fromJson).toList();

    return cards.map((e) => CreditCard(data: e)).toList();
  }

  List<Widget> _getTabs1() {
    final cards = kCreditCards.map(CreditCardData.fromJson).toList();

    return cards
        .map(
          (e) => Text(
            '*${e.number.substring(e.number.length - 4, e.number.length)}',
          ),
        )
        .toList();
  }

  List<Widget> _getChildren2() {
    return <Widget>[
      const DemoImage(
        color: Color(0xfff57c00),
        icon: Icons.directions_car,
        label: 'Orange coupe',
      ),
      const DemoImage(
        color: Color(0xff1565c0),
        icon: Icons.time_to_leave,
        label: 'Blue sedan',
      ),
      const DemoImage(
        color: Color(0xffc62828),
        icon: Icons.electric_car,
        label: 'Red sport EV',
      ),
    ];
  }

  List<Widget> _getTabs2() {
    return <Widget>[
      const Text('Image 1'),
      const Text('Image 2'),
      const Text('Image 3'),
    ];
  }

  List<Widget> _getChildren3(BuildContext context) => <Widget>[
    Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Info', style: Theme.of(context).textTheme.headlineSmall),
        const Expanded(
          child: SingleChildScrollView(
            child: Text(
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam non ex ac metus facilisis pulvinar. In id nulla tellus. Donec vehicula iaculis lacinia. Fusce tincidunt viverra nisi non ultrices. Donec accumsan metus sed purus ullamcorper tincidunt. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.',
            ),
          ),
        ),
      ],
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documents', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(flex: 2),
        const Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Divider(thickness: 1),
              Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: Text('Document 1'),
              ),
              Divider(thickness: 1),
              Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: Text('Document 2'),
              ),
              Divider(thickness: 1),
              Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: Text('Document 3'),
              ),
              Divider(thickness: 1),
            ],
          ),
        ),
      ],
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(flex: 3),
        const Expanded(
          flex: 3,
          child: Row(
            children: [
              Flexible(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('username:'),
                    Text('email:'),
                    Text('birthday:'),
                  ],
                ),
              ),
              Spacer(),
              Flexible(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('John Doe'),
                    Text('john.doe@email.com'),
                    Text('1/1/1985'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(),
        const Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SwitchListTile(
                title: Text('Darkmode'),
                value: false,
                onChanged: null,
                secondary: Icon(Icons.nightlight_outlined),
              ),
              SwitchListTile(
                title: Text('Analytics'),
                value: false,
                onChanged: null,
                secondary: Icon(Icons.analytics),
              ),
            ],
          ),
        ),
      ],
    ),
  ];

  List<Widget> _getTabs3() => <Widget>[
    const Icon(Icons.info),
    const Icon(Icons.text_snippet),
    const Icon(Icons.person),
    const Icon(Icons.settings),
  ];

  List<Widget> _getChildren4() => <Widget>[
    SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Page 1',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 50.0),
          const Text(
            '''Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur scelerisque, est ac suscipit interdum, leo lacus ultrices metus, eget tristique metus velit eget nisi. Cras ut sagittis libero, in volutpat erat. Proin luctus turpis nec molestie congue. Nam et mollis augue. Duis ornare odio vel egestas lacinia. Nam luctus venenatis diam sollicitudin elementum. Duis laoreet, mi quis luctus lacinia, nunc mauris auctor turpis, ac condimentum felis augue at purus. Integer eu dolor vehicula odio elementum vulputate vel non neque.
        Vestibulum et sapien sed quam euismod rutrum. Phasellus molestie dignissim ullamcorper. Donec eleifend sapien egestas tincidunt ornare. Pellentesque elit leo, bibendum nec augue nec, faucibus eleifend nisi. In blandit nulla sit amet congue tincidunt. Etiam dictum ornare justo, vulputate aliquam nisi egestas id. Nulla diam ipsum, pretium vitae leo et, fringilla mollis arcu. Praesent ut ipsum malesuada, posuere quam non, consectetur sem. Aenean velit dolor, laoreet sit amet lacinia quis, porta vitae tortor. Pellentesque scelerisque lacus nec velit finibus pharetra. Donec lacus arcu, consectetur eget nibh ac, viverra mollis nunc. Morbi auctor condimentum odio, ut laoreet neque maximus et. Mauris ut magna ipsum.''',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
    SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Page 2',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 50.0),
          const Text(
            '''Duis in tortor nisl. Vestibulum vitae ullamcorper urna. Aliquam at consequat mi, sit amet ultricies mauris. Nam volutpat risus mollis tortor porta volutpat. Fusce sollicitudin felis in interdum finibus. Nam ultrices volutpat posuere. Quisque eget mattis nulla. Cras sit amet consequat erat. Nam consectetur urna sem, eget faucibus quam tincidunt sed. Cras congue diam vitae turpis tristique, ut commodo nunc placerat. Nunc id risus mattis, cursus erat in, dignissim mauris.

Donec ac libero arcu. Pellentesque sollicitudin mi et lectus interdum, sit amet dignissim turpis laoreet. Aenean id sapien at felis fermentum faucibus. Fusce suscipit, odio eget vestibulum rutrum, magna nibh sagittis felis, auctor blandit tortor diam et augue. Etiam sit amet mi fermentum, sollicitudin dolor sit amet, viverra lectus. Curabitur non leo vulputate, gravida urna non, maximus lacus. Maecenas a suscipit lacus. Donec pharetra laoreet lacus, non sagittis ante aliquet eget. Sed fermentum eros a nunc molestie imperdiet. Ut quis massa vitae sem vehicula facilisis at eget eros. Proin facilisis eu dolor eu ultricies. Etiam rhoncus arcu nec diam malesuada, in malesuada ipsum rhoncus. Nunc convallis fermentum purus. Sed lobortis purus sit amet ante blandit pharetra. Cras ut turpis sem. Vivamus vel felis in elit fringilla laoreet.''',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
    SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Page 3',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 50.0),
          const Text(
            '''Phasellus a rutrum lectus. Maecenas turpis nisi, imperdiet non tellus eget, aliquam bibendum urna. Nullam tincidunt aliquam sem, eget finibus mauris commodo nec. Sed pharetra varius augue, id dignissim tortor vulputate at. Nunc sodales, nisl a ornare posuere, dolor purus pulvinar nulla, vel facilisis magna justo id tortor. Aliquam tempus nulla diam, non faucibus ligula cursus id. Maecenas vitae lorem augue. Aliquam hendrerit urna quis mi ornare pharetra. Duis vitae urna porttitor, porta elit a, egestas nibh. Etiam sollicitudin tincidunt sem pellentesque fringilla. Aenean sed mauris non augue hendrerit volutpat. Praesent consectetur metus ex, eu feugiat risus rhoncus sed. Suspendisse dapibus, nunc vel rhoncus placerat, tellus odio tincidunt mi, sed sagittis dui nulla eu erat.''',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _getTabs4() {
    return <Widget>[const Text('1'), const Text('2'), const Text('3')];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextTheme>('textTheme', textTheme));
  }
}

class DemoImage extends StatelessWidget {
  const DemoImage({
    required this.color,
    required this.icon,
    required this.label,
    super.key,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.35) ?? color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 96)),
      ),
    );
  }
}

class CreditCard extends StatelessWidget {
  final Color? color;
  final CreditCardData data;

  const CreditCard({required this.data, super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(14.0)),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(data.bank), const Icon(Icons.person, size: 36)],
            ),
          ),
          const Spacer(flex: 2),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.number,
                  style: const TextStyle(fontSize: 22.0),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Exp.'),
                const SizedBox(width: 4),
                Text(data.expiration),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(data.name, style: const TextStyle(fontSize: 16.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color));
    properties.add(DiagnosticsProperty<CreditCardData>('data', data));
  }
}

class CreditCardData {
  int index;
  bool locked;
  final String bank;
  final String name;
  final String number;
  final String expiration;
  final String cvc;

  CreditCardData({
    required this.bank,
    required this.name,
    required this.number,
    required this.expiration,
    required this.cvc,
    this.index = 0,
    this.locked = false,
  });

  factory CreditCardData.fromJson(Map<String, Object> json) => CreditCardData(
    index: json['index'] as int,
    bank: json['bank'] as String,
    name: json['name'] as String,
    number: json['number'] as String,
    expiration: json['expiration'] as String,
    cvc: json['cvc'] as String,
  );
}

const List<Map<String, Object>> kCreditCards = [
  {
    'index': 0,
    'bank': 'Aerarium',
    'name': 'John Doe',
    'number': '5234 4321 1234 4321',
    'expiration': '11/25',
    'cvc': '123',
  },
  {
    'index': 1,
    'bank': 'Aerarium',
    'name': 'John Doe',
    'number': '4234 4321 1234 4321',
    'expiration': '07/24',
    'cvc': '321',
  },
  {
    'index': 2,
    'bank': 'Aerarium',
    'name': 'John Doe',
    'number': '5234 4321 1234 4321',
    'expiration': '09/23',
    'cvc': '456',
  },
];
