import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:road_quality_tracker/pages/log_page.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import 'package:road_quality_tracker/services/run_tracker.dart';
import '../services/run_history_provider.dart';
import '../models/run.dart';

enum SelectionType { none, upload, download }

class HistoryPage extends StatefulWidget {
  final RunLogger logger;
  const HistoryPage({super.key, required this.logger});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late RunLogger logger;
  RunHistoryProvider? runHistoryProvider;
  List<Run>? completedRuns;
  bool? hasUnsyncedRuns;

  int? expandedIndex;

  SelectionType selectionType = SelectionType.none;
  Set<String> selectedRunIds = {};

  @override
  void initState() {
    super.initState();
    logger = widget.logger;
  }

  void _uploadRuns() {
    logger.log('[HISTORY PAGE] Uploading Runs.');
    setState(() {
      if (selectionType != SelectionType.upload) {
        selectionType = SelectionType.upload;
        selectedRunIds =
            completedRuns!.where((r) => !r.isSynced).map((r) => r.id).toSet();
      } else {
        selectionType = SelectionType.none;
        selectedRunIds.clear();
      }
    });
  }

  void _downloadRuns() {
    logger.log('[HISTORY PAGE] Downloading Runs.');
    setState(() {
      if (selectionType != SelectionType.download) {
        selectionType = SelectionType.download;
        selectedRunIds =
            completedRuns!.map((r) => r.id).toSet(); // select all by default
      } else {
        selectionType = SelectionType.none;
        selectedRunIds.clear();
      }
    });
  }

  bool _areAllSelected() {
    final allIds = completedRuns!.map((r) => r.id).toSet();
    return selectedRunIds.containsAll(allIds) && allIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    runHistoryProvider = context.watch<RunHistoryProvider>();
    completedRuns = runHistoryProvider!.completedRuns.reversed.toList();
    hasUnsyncedRuns = completedRuns!.any((run) => !run.isSynced);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceBright,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 17),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectionType == SelectionType.none
                        ? "Run History"
                        : selectionType == SelectionType.upload
                        ? "Upload Runs"
                        : "Download Runs",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      SizedBox(
                        height: 42,
                        width: 42,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LogPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(
                              0,
                            ), // icon is already centered
                            elevation: 1,
                          ),
                          child: const Icon(Icons.bug_report, size: 22),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: hasUnreviewedLogsNotifier,
                        builder: (context, hasUnreviewed, _) {
                          if (!hasUnreviewed) return const SizedBox.shrink();
                          return Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red, width: 1),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(
                thickness: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1,
              ),
            ],
          ),
          toolbarHeight: 70,
        ),
        body: Column(
          children: [
            const SizedBox(height: 15),
            if (selectionType != SelectionType.none)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selectionType == SelectionType.upload
                                ? Icons.cloud_upload
                                : Icons.download,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            selectionType == SelectionType.upload
                                ? "Select runs to upload."
                                : "Select runs to download.",
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "Select all",
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                          Checkbox(
                            value: _areAllSelected(),
                            onChanged: (checked) {
                              logger.log(
                                '[HISTORY PAGE] Tapped select-all checkbox, with checked=$checked.',
                              );
                              setState(() {
                                if (checked == true) {
                                  selectedRunIds =
                                      completedRuns!.map((r) => r.id).toSet();
                                } else {
                                  selectedRunIds.clear();
                                }
                              });
                            },
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ValueListenableBuilder<String?>(
                valueListenable: RunTracker.activeRunId,
                builder: (context, activeRunId, _) {
                  return ListView.builder(
                    itemCount: completedRuns!.length,
                    itemBuilder: (context, index) {
                      final run = completedRuns![index];
                      final isExpanded = expandedIndex == index;
                      final isRunning = run.id == activeRunId;

                      return HistoryEntryCard(
                        onTap: () {
                          logger.log(
                            '[HISTORY PAGE] Tapped run to see more details.',
                          );
                          setState(() {
                            expandedIndex = isExpanded ? null : index;
                          });
                        },
                        selectionType: selectionType,
                        isExpanded: isExpanded,
                        isRunning: isRunning,
                        run: run,
                        buildActionButtons: _buildActionButtons(run),
                        buildSelectionControls: _buildSelectionControls(run),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child:
                  selectionType == SelectionType.none
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                completedRuns!.isNotEmpty
                                    ? _downloadRuns
                                    : null,
                            icon: Icon(Icons.download),
                            label: Text("Download Runs"),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              elevation: 3,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed:
                                completedRuns!.isNotEmpty
                                    ? _uploadRuns
                                    : null, //hasUnsyncedRuns! ? _uploadRuns: null,
                            icon: Icon(Icons.upload),
                            label: Text("Upload Unsynced"),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              elevation: 3,
                            ),
                          ),
                        ],
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                selectionType = SelectionType.none;
                                selectedRunIds.clear();
                              });
                            },
                            icon: Icon(Icons.close),
                            label: Text("Cancel"),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (selectionType == SelectionType.upload) {
                                logger.log('[HISTORY PAGE] Uploading runs.');
                                context
                                    .read<RunHistoryProvider>()
                                    .uploadSelectedRuns(
                                      context,
                                      selectedRunIds,
                                    );
                              } else if (selectionType ==
                                  SelectionType.download) {
                                logger.log('[HISTORY PAGE] Downloading runs.');
                                context
                                    .read<RunHistoryProvider>()
                                    .downloadSelectedRuns(
                                      context,
                                      selectedRunIds,
                                    );
                              }
                              setState(() {
                                selectionType = SelectionType.none;
                                selectedRunIds.clear();
                              });
                            },
                            icon: Icon(
                              selectionType == SelectionType.upload
                                  ? Icons.upload
                                  : Icons.download,
                            ),
                            label: Text(
                              selectionType == SelectionType.upload
                                  ? "Submit Upload"
                                  : "Download Runs",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ],
                      ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionControls(Run run) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            run.isSynced ? Icons.cloud_done : Icons.cloud_upload,
            color: run.isSynced ? Colors.green[800] : Colors.grey,
            size: 20,
          ),
          tooltip: "Sync status",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: null, // or show info
        ),
        Checkbox(
          value: selectedRunIds.contains(run.id),
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                selectedRunIds.add(run.id);
              } else {
                selectedRunIds.remove(run.id);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(Run run) {
    return Row(
      // mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            run.isSynced ? Icons.cloud_done : Icons.cloud_upload,
            color: run.isSynced ? Colors.green[800] : Colors.grey,
            size: 20,
          ),
          tooltip: "Sync status",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: null, // or show info
        ),
        IconButton(
          icon: Icon(Icons.delete, size: 20),
          tooltip: "Rename run",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _deleteRun(context, run),
        ),
        IconButton(
          icon: Icon(Icons.edit, size: 20),
          tooltip: "Rename run",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _editRun(context, run),
        ),
      ],
    );
  }

void _editRun(BuildContext context, Run run) {
  logger.log('[HISTORY PAGE] Opening Edit Run Dialog.');
  final nameController = TextEditingController(text: run.name);

  final customVehicleController = TextEditingController();
  final List<String> vehicleOptions = ['Bike', 'E-Scooter', 'Car', 'Custom'];
  if (!vehicleOptions.contains(run.vehicleType)) {
    customVehicleController.text = run.vehicleType;
  }
  String selectedVehicle =
      vehicleOptions.contains(run.vehicleType) ? run.vehicleType : 'Custom';

  List<String> tags = List<String>.from(run.tags);
  final tagInputController = TextEditingController();

  String capitalise(String sentence) {
    return sentence
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDlgState) {
          void addTag(String raw) {
            final trimmed = raw.trim();
            if (trimmed.isEmpty) return;
            final cap = capitalise(trimmed);
            if (!tags.contains(cap)) setDlgState(() => tags.add(cap));
            tagInputController.clear();
          }

          void removeTag(String t) => setDlgState(() => tags.remove(t));

          final theme = Theme.of(context);
          final mq = MediaQuery.of(context);
          final maxDialogHeight = mq.size.height * 0.78; // keep under keyboard

          return SafeArea(
            child: AlertDialog(
              scrollable: true,                      
              clipBehavior: Clip.antiAlias,           
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),

              title: Row(
                children: [
                  Expanded(
                    child: Text('Edit Run Information', style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () {
                      logger.log('[HISTORY PAGE] Canceled Edit Run Dialog.');
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),

              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 360,                       
                  maxHeight: maxDialogHeight,        
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Theme(
                    data: theme.copyWith(
                      inputDecorationTheme: const InputDecorationTheme(
                        border: UnderlineInputBorder(),               
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        isDense: false,
                        labelStyle: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Run name
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Run Name',
                            hintText: 'Enter a new name',
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Vehicle type
                        DropdownButtonFormField<String>(
                          value: selectedVehicle,
                          style: const TextStyle(fontWeight: FontWeight.w400),
                          decoration: const InputDecoration(labelText: 'Vehicle Type'),
                          items: vehicleOptions.map((v) {
                            IconData? icon;
                            switch (v) {
                              case 'Bike':       icon = Icons.directions_bike; break;
                              case 'E-Scooter':  icon = Icons.electric_scooter; break;
                              case 'Car':        icon = Icons.directions_car; break;
                              case 'Custom':     icon = Icons.person_add; break;
                            }
                            return DropdownMenuItem<String>(
                              value: v,
                              // icon only in the dropdown menu:
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(v, style: theme.textTheme.bodyMedium),
                                  if (icon != null)
                                    Icon(icon, size: 20, color: Colors.grey[600]),
                                ],
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (context) => vehicleOptions.map((v) =>
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(v, style: theme.textTheme.bodyMedium),
                            ),
                          ).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDlgState(() {
                              selectedVehicle = value;
                              if (value != 'Custom') customVehicleController.clear();
                            });
                          },
                        ),

                        if (selectedVehicle == 'Custom') const SizedBox(height: 12),
                        if (selectedVehicle == 'Custom')
                          TextField(
                            controller: customVehicleController,
                            decoration: const InputDecoration(
                              labelText: 'Your Vehicle',
                              hintText: 'e.g., Motorcycle, Tractor ..',
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Tags input + chips
                        TextField(
                          controller: tagInputController,
                          onSubmitted: addTag,
                          decoration: InputDecoration(
                            labelText: 'Add Tag',
                            hintText: 'Type a tag and press Enter',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Add Tag',
                              onPressed: () => addTag(tagInputController.text),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text('Tags', style: theme.textTheme.titleSmall),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in tags)
                                InputChip(
                                  label: Text(t, style: const TextStyle(fontSize: 11)),
                                  onDeleted: () => removeTag(t),
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide.none,
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              if (tags.isEmpty)
                                Text('No tags yet',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                TextButton(
                  onPressed: () {
                    logger.log('[HISTORY PAGE] Canceled Edit Run Dialog.');
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () async {
                    logger.log('[HISTORY PAGE] Saving edits for run ${run.id}.');

                    // Name
                    run.name = nameController.text.trim().isEmpty
                        ? run.name
                        : nameController.text.trim();

                    // Vehicle
                    final newVehicle = (selectedVehicle == 'Custom')
                        ? (customVehicleController.text.trim().isEmpty
                            ? run.vehicleType
                            : capitalise(customVehicleController.text.trim()))
                        : selectedVehicle;
                    run.vehicleType = newVehicle;

                    // Tags
                    run.tags = tags;

                    // Persist through your provider
                    runHistoryProvider!.updateRun(run);

                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {}); // refresh History list
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  void _deleteRun(BuildContext context, Run run) {
    logger.log('[HISTORY PAGE] Opening Delete Run Dialog.');
    ColorScheme appColorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Delete Run"),
            content: Text(
              "Are you sure you want to delete:\n\n > ${run.name} ? \n\nThis cannot be undone!",
            ),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () {
                  logger.log('[HISTORY PAGE] Canceled Delete Run Dialog.');
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColorScheme.secondary,
                  foregroundColor: appColorScheme.onSecondary,
                ),
                child: Text("Delete"),
                onPressed: () async {
                  logger.log('[HISTORY PAGE] Deleting run with id ${run.id}.');
                  await run.delete();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
    );
  }
}

class HistoryEntryCard extends StatelessWidget {
  final Widget buildActionButtons;
  final Widget buildSelectionControls;
  final SelectionType selectionType;
  final bool isRunning;
  final Run run;
  final bool isExpanded;
  final VoidCallback onTap;

  const HistoryEntryCard({
    super.key,
    required this.selectionType,
    required this.isRunning,
    required this.buildActionButtons,
    required this.buildSelectionControls,
    required this.onTap,
    required this.run,
    this.isExpanded = false,
  });

  String shortenRunName(String name) {
    if (!name.contains(',')) return name;
    final parts = name.split(',');
    if (parts.isEmpty) return name;

    final day = parts.first.trim();
    final abbr = day.substring(0, 3); // Mon, Tue, Wed …
    return '$abbr,${parts.sublist(1).join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      () {
        switch (run.vehicleType) {
          case 'Bike':
            return Icons.directions_bike;
          case 'E-Scooter':
            return Icons.electric_scooter;
          case 'Car':
            return Icons.directions_car;
          default:
            return Icons.person_add;
        }
      }(),
      size: 20,
      color: Colors.grey[600],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 1.0,
                  vertical: 3.0,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(
                    shortenRunName(run.name),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      icon,
                      SizedBox(width: 6),
                      Text(
                        "Run on ${run.startTime.toLocal().toString().split('.').first.substring(0, 16)}",
                      ),
                    ],
                  ),
                  trailing:
                      selectionType != SelectionType.none
                          ? buildSelectionControls
                          : isRunning
                          ? Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Text(
                              "Currently Running ..",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.green[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          : buildActionButtons,
                ),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Text(
                            "Vehicle Type: ",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(run.vehicleType),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Text(
                            "Duration: ",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(run.getFormattedDuration()),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Text(
                            "Points: ",
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text("${run.runPoints.length}"),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tags section
                      if (run.tags.isNotEmpty) ...[
                        Text(
                          "Tags:",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in run.tags)
                                Chip(
                                  label: Text(
                                    t,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: -2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide.none,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            Text(
                              "Tags:",
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(" No Tags"),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
