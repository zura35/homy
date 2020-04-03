import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<HomeItem> items;
  Firestore store;
  int updateCounter;

  @override
  void initState() {
    items = List();
    store = Firestore.instance;
    super.initState();
  }

  addItemDialog() {
    String name;
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text("Add an item"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("Please enter a name"),
                TextField(
                  onChanged: (value) {
                    name = value;
                  },
                ),
              ],
            ),
            actions: <Widget>[
              FlatButton(
                child: Text("Add"),
                onPressed: () {
                  // Add item
                  store
                      .collection("homeitems")
                      .document()
                      .setData(HomeItem(name).toMap());
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  countItemDialog(DocumentSnapshot item) async {
    Map<String, dynamic> update = item.data;
    updateCounter = update['counter'];

    await showDialog(
      context: context,
      builder: (_) {
        /// Use StatefulBuilder to avoid updating ListView out of this dialog
        return StatefulBuilder(builder: (_, state) {
          return SimpleDialog(
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () {
                        state(() {
                          if (update['counter'] > 0)
                            updateCounter = --update['counter'];
                        });
                      }),
                  Expanded(
                    child: Center(
                      child: Text('$updateCounter'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      state(() {
                        updateCounter = ++update['counter'];
                      });
                    },
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
    item.reference.updateData(update);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'homy',
          style: TextStyle(
            fontFamily: 'Oleo Script',
            fontSize: 24.0,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: store.collection('homeitems').snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.hasError) return Text('Error: ${snapshot.error}');
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return CircularProgressIndicator();
            default:
              if (snapshot.data.documents.length == 0) {
                return Center(
                  child: Text('No Item'),
                );
              }
              return ListView.builder(
                  itemCount: snapshot.data.documents.length,
                  itemBuilder: (context, i) {
                    DocumentSnapshot item = snapshot.data.documents[i];
                    return Dismissible(
                      key: Key(DateTime.now().toIso8601String()),
                      child: ListTile(
                        title: Text(item['name'] ?? 'N/A'),
                        trailing: Text('${item['counter'] ?? 'N/A'}'),
                        onTap: () {
                          // Open Counter dialog
                          countItemDialog(item);
                        },
                      ),
                      onDismissed: (direction) {
                        // Delete item
                        String name = item['name'];
                        store.runTransaction((Transaction tx) async {
                          DocumentSnapshot postSnapshot =
                              await tx.get(item.reference);
                          if (postSnapshot.exists) {
                            await tx.delete(item.reference);
                          }
                        });

                        Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text("Removed $name"),
                          action: SnackBarAction(
                            label: "UNDO",
                            onPressed: () {
                              store.runTransaction((tx) async {
                                tx.set(item.reference, item.data);
                              });
                            },
                          ),
                        ));
                      },
                    );
                  });
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          addItemDialog();
        },
        child: Icon(
          Icons.add,
          color: Colors.black,
        ),
        backgroundColor: Colors.white,
      ),
    );
  }
}

class HomeItem {
  String name;
  int counter = 0;

  HomeItem(this.name);

  void increment() {
    counter++;
  }

  void decrement() {
    if (counter == 0) return;
    counter--;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'counter': counter,
    };
  }
}
