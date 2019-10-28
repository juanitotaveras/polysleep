import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:polysleep/features/schedule_manager/domain/entities/segment_datetime.dart';
import 'package:polysleep/features/schedule_manager/domain/entities/sleep_schedule.dart';
import 'package:polysleep/features/schedule_manager/domain/entities/sleep_segment.dart';
import 'package:polysleep/features/schedule_manager/presentation/bloc/choose_template_view_model.dart';
import 'package:polysleep/features/schedule_manager/presentation/bloc/view_model_provider.dart';
import 'package:polysleep/features/schedule_manager/presentation/widgets/current_schedule_graphic.dart';
import 'package:polysleep/injection_container.dart';

class ChooseTemplatePresenter {
  final _context;
  final ChooseTemplateViewModel _viewModel;
  ChooseTemplatePresenter(this._context, this._viewModel);
}

class ChooseTemplatePage extends StatelessWidget {
  final _viewModel = sl<ChooseTemplateViewModel>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Choose a template')),
      body: ViewModelProvider(bloc: this._viewModel, child: pageBody()),
    );
  }

  Widget templateChooserRow(
      String name, int sleepMin, int wakeMin, String difficulty) {
    return InkWell(
        onTap: () {
          print('tapped!');
        },
        child: Container(
            padding: EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Text(name),
                ),
                Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('8h2m asleep'),
                        Text('13h awake')
                      ],
                    )),
                Expanded(child: Text(difficulty)),
                Expanded(child: Icon(Icons.info))
              ],
            )));
  }

  Widget dataTable(List<SleepSchedule> schedules) {
    final rows = schedules
        .map((sched) => DataRow(cells: [
              DataCell(Text(sched.name)),
              DataCell(Text('14')),
              DataCell(Row(
                  children: [Text('15'), Expanded(child: Icon(Icons.info))])),
            ]))
        .toList();
    return ListView(children: [
      DataTable(
        columns: [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('hours')),
          DataColumn(label: Text('difficulty')),
          // DataColumn(label: Text('')),
        ],
        rows: rows,
      )
    ]);
  }

  Widget scheduleList(List<Widget> templateRows) {
    return ListView(
      children: templateRows,
      // children: <Widget>[
      //   ...templateRows,
      //   // templateChooserRow('Monophasic', 1, 1, 'Easy')
      // ],
    );
  }

  Widget pageBody() {
    return StreamBuilder<List<SleepSchedule>>(
        stream: _viewModel.schedules.stream,
        initialData: null,
        builder: (context, schedulesStream) {
          final List<Widget> templateRows = [];
          final schedules = _viewModel.schedules.stream.value;
          if (schedules != null) {
            schedules.forEach((SleepSchedule sched) {
              templateRows.add(
                  templateChooserRow(sched.name, 100, 200, sched.difficulty));
            });
          }
          return Column(
            children: <Widget>[
              Expanded(
                  flex: 2,
                  child: Container(child: scheduleList(templateRows)
                      /*dataTable(schedules)*/)),
              Expanded(
                child: CurrentScheduleGraphic(
                  currentTime: DateTime.now(),
                  currentSchedule: SleepSchedule(name: "", segments: [
                    SleepSegment(
                        startTime: SegmentDateTime(hr: 1),
                        endTime: SegmentDateTime(hr: 3))
                  ]),
                ),
              )
            ],
          );
        });
  }
}