import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ToDoApp());
}

class ToDoApp extends StatelessWidget {
  const ToDoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Tarefas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginScreen(),
    );
  }
}

class Task {
  String id;
  String title;
  String description;
  DateTime dueDate;
  String category;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'category': category,
    };
  }

  static Task fromJson(Map<String, dynamic> json, String id) {
    return Task(
      id: id,
      title: json['title'],
      description: json['description'],
      dueDate: DateTime.parse(json['dueDate']),
      category: json['category'],
    );
  }
}

class FirebaseTaskManager {
  final String firebaseUrl =
      'https://to-do-list-22d97-default-rtdb.firebaseio.com/tasks.json';

  Future<List<Task>> fetchTasks() async {
    final response = await http.get(Uri.parse(firebaseUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data.entries.map((e) => Task.fromJson(e.value, e.key)).toList();
    } else {
      throw Exception('Erro ao carregar tarefas!');
    }
  }

  Future<void> addTask(Task task) async {
    final response = await http.post(
      Uri.parse(firebaseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(task.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao adicionar tarefa! Código: ${response.statusCode}');
    }
  }

  Future<void> updateTask(String id, Task task) async {
    final url =
        'https://to-do-list-22d97-default-rtdb.firebaseio.com/tasks/$id.json';
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(task.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar tarefa!');
    }
  }

  Future<void> deleteTask(String id) async {
    final url =
        'https://to-do-list-22d97-default-rtdb.firebaseio.com/tasks/$id.json';
    final response = await http.delete(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Erro ao excluir tarefa!');
    }
  }
}

class LoginScreen extends StatelessWidget {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usuarioController,
              decoration: const InputDecoration(labelText: 'Usuário'),
            ),
            TextField(
              controller: senhaController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
              child: const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Task>> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = FirebaseTaskManager().fetchTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Tarefas')),
      body: FutureBuilder<List<Task>>(
        future: _tasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar tarefas!'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma tarefa disponível.'));
          } else {
            final tasks = snapshot.data!;
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isCloseToDeadline =
                    task.dueDate.difference(DateTime.now()).inHours < 24;
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(10),
                  color: isCloseToDeadline ? Colors.red[100] : Colors.white,
                  child: ListTile(
                    title: Text(task.title),
                    subtitle: Text(
                      '${task.description}\nVencimento: ${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TaskScreen(task: task, isEdit: true),
                          ),
                        ).then((_) {
                          setState(() {
                            _tasks = FirebaseTaskManager().fetchTasks();
                          });
                        });
                      },
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TaskScreen(),
          ),
        ).then((_) {
          setState(() {
            _tasks = FirebaseTaskManager().fetchTasks();
          });
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TaskScreen extends StatefulWidget {
  final Task? task;
  final bool isEdit;

  const TaskScreen({super.key, this.task, this.isEdit = false});

  @override
  // ignore: library_private_types_in_public_api
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String category = 'Geral';
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.task != null) {
      titleController.text = widget.task!.title;
      descriptionController.text = widget.task!.description;
      selectedDate = widget.task!.dueDate;
      category = widget.task!.category;
    }
  }

  Future<void> _saveTask() async {
    if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final task = Task(
        id: widget.isEdit ? widget.task!.id : '',
        title: titleController.text,
        description: descriptionController.text,
        dueDate: selectedDate,
        category: category,
      );

      if (widget.isEdit) {
        await FirebaseTaskManager().updateTask(task.id, task);
      } else {
        await FirebaseTaskManager().addTask(task);
      }

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarefa salva com sucesso!')),
      );

      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar tarefa: $e')),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.isEdit ? 'Editar Tarefa' : 'Criar Tarefa')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vencimento:'),
                TextButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        selectedDate = pickedDate;
                      });
                    }
                  },
                  child: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isSaving)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _saveTask,
                child: const Text('Salvar'),
              ),
          ],
        ),
      ),
    );
  }
}
