import 'dart:async';
import 'dart:ui';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/widgets.dart';
import 'package:polysleep/core/usecases/usecase.dart';
import 'package:polysleep/core/utils.dart';
import 'package:polysleep/features/schedule_manager/data/repositories/schedule_editor_repository_impl.dart';
import 'package:polysleep/features/schedule_manager/domain/entities/segment_datetime.dart';
import 'package:polysleep/features/schedule_manager/domain/entities/sleep_schedule.dart';
import 'package:polysleep/features/schedule_manager/domain/entities/sleep_segment.dart';
// import 'package:polysleep/features/schedule_manager/domain/usecases/create_temporary_segment.dart';
import 'package:polysleep/features/schedule_manager/domain/usecases/get_current_schedule.dart';
import 'package:polysleep/features/schedule_manager/domain/usecases/get_default_schedule.dart';
import 'package:polysleep/features/schedule_manager/domain/usecases/save_current_schedule.dart';
import 'package:polysleep/features/schedule_manager/domain/usecases/create_temporary_segment.dart';
import 'package:rxdart/rxdart.dart';
import './bloc.dart';

class ScheduleEditorViewModel {
  final selectedSegmentSubject = BehaviorSubject<SleepSegment>();
  Stream<SleepSegment> get selectedSegmentStream =>
      selectedSegmentSubject.stream;
  SleepSegment get selectedSegment => selectedSegmentSubject.value;

  final loadedSegmentsSubject = BehaviorSubject<List<SleepSegment>>();
  Stream<List<SleepSegment>> get loadedSegmentsStream =>
      loadedSegmentsSubject.stream;
  List<SleepSegment> get loadedSegments => loadedSegmentsSubject.value;

  dispose() {
    selectedSegmentSubject.close();
    loadedSegmentsSubject.close();
  }
}

class ScheduleEditorBloc
    extends Bloc<ScheduleEditorEvent, ScheduleEditorState> {
  final GetCurrentSchedule getCurrentSchedule;
  final GetDefaultSchedule getDefaultSchedule;
  final SaveCurrentSchedule saveCurrentSchedule;

  ScheduleEditorBloc(
      {@required this.getCurrentSchedule,
      @required this.getDefaultSchedule,
      @required this.saveCurrentSchedule}) {
    assert(getCurrentSchedule != null);
    assert(getDefaultSchedule != null);
    assert(saveCurrentSchedule != null);

    _eventHandlerSubject.stream.listen((ScheduleEditorEvent event) {
      handleEvent(event);
    });
  }

// VIEW MODEL
  final viewModel = ScheduleEditorViewModel();

// TODO: Seed with LoadSchedule so we never even have to call it
  final _eventHandlerSubject = BehaviorSubject<ScheduleEditorEvent>();

  @override
  void dispose() {
    viewModel.dispose();
    _eventHandlerSubject.close();
    super.dispose();
  }

  void handleEvent(ScheduleEditorEvent event) async {
    // LoadSchedule
    if (event is LoadSchedule) {
      // TODO: This use case should actually do both of these things
      final resp = await getCurrentSchedule(NoParams());
      resp.fold((failure) async {
        final defResp = await getDefaultSchedule(NoParams());
        defResp.fold((failure) async {
          viewModel.loadedSegmentsSubject.add([]);
        }, (schedule) async {
          viewModel.loadedSegmentsSubject.add(schedule.segments);
        });
      }, (schedule) async {
        viewModel.loadedSegmentsSubject.add(schedule.segments);
      });
    }

    // TemporarySegmentCreated
    else if (event is TemporarySleepSegmentCreated) {
      DateTime t = GridTapToTimeConverter.touchInputToTime(
          event.touchCoord, event.hourPixels, 30);
      DateTime endTime = t.add(Duration(minutes: 60));
      viewModel.selectedSegmentSubject
          .add(SleepSegment(startTime: t, endTime: endTime));
    }

    // TemporarySleepSegmentDragged
    else if (event is TemporarySleepSegmentDragged) {
      final t = GridTapToTimeConverter.touchInputToTime(
          event.touchCoord, event.hourSpacing, 15);
      SleepSegment currentSegment = viewModel.selectedSegment;
      if (t.compareTo(currentSegment.startTime) != 0) {
        final selectedSegment = SleepSegment(
            startTime: t,
            endTime:
                t.add(Duration(minutes: currentSegment.getDurationMinutes())));
        viewModel.selectedSegmentSubject.add(selectedSegment);
      }
    }

    // Temporary Sleep SEgment Start Time Dragged
    else if (event is TemporarySleepSegmentStartTimeDragged) {
      final t = GridTapToTimeConverter.touchInputToTime(
          event.touchCoord, event.hourSpacing, 5);
      SleepSegment currentSegment = viewModel.selectedSegment;
      if (t.compareTo(currentSegment.startTime) != 0) {
        final newSeg =
            SleepSegment(startTime: t, endTime: currentSegment.endTime);
        viewModel.selectedSegmentSubject.add(newSeg);
      }
    }

    // end time dragged
    else if (event is TemporarySleepSegmentEndTimeDragged) {
      final t = GridTapToTimeConverter.touchInputToTime(
          event.touchCoord, event.hourSpacing, 5);
      SleepSegment currentSegment = viewModel.selectedSegment;
      if (t.compareTo(currentSegment.startTime) != 0) {
        final newSeg =
            SleepSegment(startTime: currentSegment.startTime, endTime: t);
        viewModel.selectedSegmentSubject.add(newSeg);
      }
    }

    // save changes pressed
    else if (event is SaveChangesPressed) {
      SleepSchedule schedule =
          SleepSchedule(segments: viewModel.loadedSegments);
      final resp = await saveCurrentSchedule(Params(schedule: schedule));
      resp.fold((failure) async {
        // print('there has been an error');
        // show error state
      }, (updatedSchedule) async {
        // print(' great success!');
        print(updatedSchedule);
      });
    }

    // selected segment cancelled
    else if (event is SelectedSegmentCancelled) {
      final lSegments = viewModel.loadedSegments;
      final currentlyEditing =
          lSegments.where((seg) => seg.isBeingEdited).toList();
      if (currentlyEditing.length == 0) {
        viewModel.loadedSegmentsSubject.add([...lSegments]);
        viewModel.selectedSegmentSubject.add(null);
      } else {
        final segs = lSegments
            .map((seg) => SleepSegment(
                startTime: seg.startTime,
                endTime: seg.endTime,
                isBeingEdited: false,
                name: seg.name))
            .toList();
        viewModel.loadedSegmentsSubject.add(segs);
        viewModel.selectedSegmentSubject.add(null);
      }
    }

    // loaded segment tapped
    else if (event is LoadedSegmentTapped) {
      final segs = viewModel.loadedSegments
          .asMap()
          .map((idx, seg) {
            return MapEntry(
                idx,
                SleepSegment(
                    startTime: seg.startTime,
                    endTime: seg.endTime,
                    name: seg.name,
                    isBeingEdited: idx == event.idx));
          })
          .values
          .toList();
      final selectedSegment =
          segs.where((seg) => seg.isBeingEdited).toList()[0];
      viewModel.loadedSegmentsSubject.add(segs);
      viewModel.selectedSegmentSubject.add(selectedSegment);
    }

    // selected segment saved
    else if (event is SelectedSegmentSaved) {
      final lSegments = viewModel.loadedSegments;
      final sSegment = viewModel.selectedSegment;
      final currentlyEdited =
          lSegments.where((seg) => seg.isBeingEdited).toList();
      if (currentlyEdited.length == 0) {
        // this is a new segment
        viewModel.loadedSegmentsSubject.add([...lSegments, sSegment]);
        viewModel.selectedSegmentSubject.add(null);
      } else {
        final segs = lSegments.map((seg) {
          if (seg.isBeingEdited) {
            final sel = sSegment;
            return SleepSegment(
                startTime: sel.startTime,
                endTime: sel.endTime,
                name: sel.name,
                isBeingEdited: false);
          }
          return SleepSegment(
              startTime: seg.startTime,
              endTime: seg.endTime,
              name: seg.name,
              isBeingEdited: false);
        }).toList();
        viewModel.loadedSegmentsSubject.add(segs);
        viewModel.selectedSegmentSubject.add(null);
      }
    }
  }

  @override
  ScheduleEditorState get initialState => Init();

  @override
  void dispatch(ScheduleEditorEvent event) {
    // TODO: implement dispatch
    _eventHandlerSubject.add(event);
    // print('LE DISPATCH: $event');
    super.dispatch(event);
  }

  @override
  Stream<ScheduleEditorState> mapEventToState(
    ScheduleEditorEvent event,
  ) async* {}
}

// TODO: Put these into an EventMapper class
class GridTapToTimeConverter {
  static DateTime touchInputToTime(
      Offset tapPosition, double hourSpacing, int granularity) {
    var hr = tapPosition.dy ~/ hourSpacing;
    var min = ((tapPosition.dy % hourSpacing) ~/ granularity) * granularity;
    return SegmentDateTime(hr: hr, min: min);
  }
}

class SegmentDragToTimeChangeConverter {
  static DateTime dragInputToNewTime(DragUpdateDetails details,
      RenderBox calendarGrid, double hourSpacing, int granularity) {
    assert(calendarGrid != null);
    var relativeTapPos = calendarGrid.globalToLocal(details.globalPosition);
    return GridTapToTimeConverter.touchInputToTime(
        relativeTapPos, hourSpacing, granularity);
  }
}
