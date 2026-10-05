import 'dart:async';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../session/session_model.dart';
import 'models.dart';

/// The dialog loads each visible month from the API, independently of the week.
/// A missing marker after a failed read is never presented as a confirmed empty day.
Future<DateTime?> selectHoursDate(
  BuildContext context,
  SessionModel model,
) async {
  final workspace = model.workspace!;
  final initialDate = workspaceToday(workspace.timezone);
  final revision = model.sessionRevision;
  final dates = ValueNotifier<Set<String>>({
    for (final entry in model.page?.entries ?? <HoursEntry>[])
      dateKey(entry.date),
  });
  final status = ValueNotifier<String>('Loading entry dates…');
  final requested = <String>{};
  var pending = 0;
  var failed = false;
  var active = true;
  void requestMonth(DateTime date) {
    final start = DateTime(date.year, date.month);
    final key = dateKey(start);
    if (!active || !requested.add(key)) return;
    pending++;
    unawaited(
      Future<void>(() async {
        try {
          final page = await model.hours.range(
            workspace.id,
            start,
            DateTime(date.year, date.month + 1, 0),
          );
          if (active && revision == model.sessionRevision) {
            dates.value = {
              ...dates.value,
              for (final entry in page.entries) dateKey(entry.date),
            };
          }
        } catch (_) {
          failed = true;
        } finally {
          pending--;
          if (active) {
            status.value = failed
                ? 'Could not load some entry dates. Reopen the calendar to retry.'
                : pending > 0
                ? 'Loading entry dates…'
                : 'Orange dots mark dates with entries.';
          }
        }
      }),
    );
  }

  requestMonth(initialDate);
  try {
    final result = await showCalendarDatePicker2Dialog(
      context: context,
      useRootNavigator: false,
      dialogSize: Size(360, 430),
      value: [initialDate],
      dialogBackgroundColor: mhpColor(context, brandSurface),
      borderRadius: BorderRadius.circular(16),
      config: CalendarDatePicker2WithActionButtonsConfig(
        firstDayOfWeek: 1,
        disableMonthPicker: true,
        controlsTextStyle: TextStyle(
          fontSize: 16,
          color: mhpColor(context, brandInk),
        ),
        selectedDayHighlightColor: mhpColor(context, brandAction),
        dayBuilder:
            ({
              required date,
              decoration,
              isDisabled,
              isSelected,
              isToday,
              textStyle,
            }) {
              requestMonth(date);
              return ValueListenableBuilder<Set<String>>(
                valueListenable: dates,
                builder: (_, values, _) => Semantics(
                  label:
                      '${dateKey(date)}${values.contains(dateKey(date)) ? ', has an hours entry' : ''}',
                  child: Container(
                    decoration: decoration,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${date.day}', style: textStyle),
                        SizedBox(
                          height: 6,
                          child: values.contains(dateKey(date))
                              ? Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isSelected == true
                                        ? Colors.white
                                        : mhpColor(context, brandAction),
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
      ),
      builder: (_, dialog) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: dialog!),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (_, message, _) => Material(
                color: mhpColor(context, brandSurface),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(message),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final selected = result?.firstOrNull;
    return revision == model.sessionRevision &&
            selected != null &&
            dateKey(selected) != dateKey(initialDate)
        ? selected
        : null;
  } finally {
    active = false;
    dates.dispose();
    status.dispose();
  }
}
