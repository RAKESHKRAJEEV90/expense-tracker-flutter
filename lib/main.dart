import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/expense.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.orangeAccent,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 14.0),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal, width: 2.0),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Expense> _expenses = [];
  List<String> _categories = [
    'Food',
    'Transportation',
    'Entertainment',
    'Bills',
    'Other'
  ];
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _newCategoryController = TextEditingController();
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  void _addCategory(String newCategory) {
    if (newCategory.isNotEmpty && !_categories.contains(newCategory)) {
      setState(() {
        _categories.add(newCategory);
        _selectedCategory = newCategory;
      });
      _saveCategories();
    }
  }

  void _saveCategories() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('categories', _categories);
  }

  void _loadCategories() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _categories = prefs.getStringList('categories') ??
          ['Food', 'Transportation', 'Entertainment', 'Bills', 'Other'];
    });
  }

  void _loadExpenses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _expenses = (prefs.getStringList('expenses') ?? [])
          .map((item) => Expense.fromJson(json.decode(item)))
          .toList();
    });
  }

  void _saveExpenses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> expensesJson =
        _expenses.map((expense) => json.encode(expense.toJson())).toList();
    prefs.setStringList('expenses', expensesJson);
  }

  void _addExpense() {
    if (_formKey.currentState!.validate() &&
        _selectedCategory != 'add_new_category') {
      setState(() {
        _expenses.add(Expense(
          id: const Uuid().v4(),
          title: _titleController.text,
          amount: double.parse(_amountController.text),
          date: _selectedDate,
          category: _selectedCategory,
        ));
        _titleController.clear();
        _amountController.clear();
        _selectedCategory = 'Food';
        _selectedDate = DateTime.now();
      });
      _saveExpenses();
    }
  }

  void _deleteExpense(String id) {
    setState(() {
      _expenses.removeWhere((expense) => expense.id == id);
    });
    _saveExpenses();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expense Tracker'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Expenses'),
              Tab(icon: Icon(Icons.add), text: 'Add Expense'),
              Tab(icon: Icon(Icons.pie_chart), text: 'Statistics'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildExpensesList(),
            _buildAddExpenseForm(),
            _buildStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    return ListView.builder(
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return Dismissible(
          key: Key(expense.id),
          background: Container(
            color: const Color.fromARGB(255, 224, 50, 37),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: const Color.fromARGB(255, 53, 228, 79),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.edit, color: Colors.white),
          ),
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              _deleteExpense(expense.id);
            }
          },
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              await _showEditExpenseDialog(expense);
              return false;
            }
            return true;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Card(
              child: ListTile(
                title: Text(expense.title),
                subtitle: Text(
                    '${expense.amount.toStringAsFixed(2)} - ${expense.category}'),
                trailing: Text(_formatDate(expense.date)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddExpenseForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8.0),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: [
                  ..._categories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      )),
                  const DropdownMenuItem(
                    value: 'add_new_category',
                    child: Text('Add New Category',
                        style: TextStyle(color: Colors.blue)),
                  ),
                ],
                onChanged: (value) {
                  if (value == 'add_new_category') {
                    _showAddCategoryDialog();
                  } else {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: ${_formatDate(_selectedDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('Select Date'),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: _addExpense,
                child: const Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Category'),
          content: TextField(
            controller: _newCategoryController,
            decoration: const InputDecoration(hintText: "Enter new category"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                _addCategory(_newCategoryController.text);
                _newCategoryController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatistics() {
    Map<String, double> categoryTotals = {};
    double total = 0;

    for (var expense in _expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
      total += expense.amount;
    }

    List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      return PieChartSectionData(
        color: Colors.primaries[
            categoryTotals.keys.toList().indexOf(entry.key) %
                Colors.primaries.length],
        value: entry.value,
        title:
            '${entry.key}\n${(entry.value / total * 100).toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 0,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Total Expenses: ${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }

  Future<void> _showEditExpenseDialog(Expense expense) async {
    _titleController.text = expense.title;
    _amountController.text = expense.amount.toString();
    _selectedCategory = expense.category;
    _selectedDate = expense.date;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${_formatDate(_selectedDate)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () => _selectDate(context),
                        child: const Text('Select Date'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _updateExpense(expense);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _updateExpense(Expense oldExpense) {
    setState(() {
      int index = _expenses.indexWhere((e) => e.id == oldExpense.id);
      if (index != -1) {
        _expenses[index] = Expense(
          id: oldExpense.id,
          title: _titleController.text,
          amount: double.parse(_amountController.text),
          date: _selectedDate,
          category: _selectedCategory,
        );
      }
    });
    _saveExpenses();
  }
}
