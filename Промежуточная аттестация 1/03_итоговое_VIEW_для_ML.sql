/*
  ПРОЕКТ: Предиктивное обслуживание промышленного оборудования
  ШАГ 03: Итоговое представление для машинного обучения

  Зависимость: сначала выполнить 02_обогащенное_представление_телеметрии.sql.

  Единица наблюдения: машина и момент прогноза (конец часового интервала).
  Признаки: агрегаты показаний за один час непосредственно перед прогнозом,
  характеристики машины и история, доступная строго до момента прогноза.
  Цель: failure_next_6h = 1, если BREAKDOWN начнётся в следующие 6 часов.
*/

CREATE OR REPLACE VIEW public.v_predictive_maintenance_ml AS
WITH sensor_hourly AS (
    SELECT
        e.machine_id,
        date_trunc('hour', e.recorded_at) + INTERVAL '1 hour' AS prediction_time,
        e.sensor_type_code,
        COUNT(*) AS readings_count,
        AVG(e.numeric_value) AS average_value,
        MIN(e.numeric_value) AS minimum_value,
        MAX(e.numeric_value) AS maximum_value,
        STDDEV_SAMP(e.numeric_value) AS standard_deviation,
        SUM(e.is_out_of_range) AS out_of_range_count
    FROM public.v_sensor_readings_enriched AS e
    WHERE e.quality_status = 'VALID'
    GROUP BY
        e.machine_id,
        date_trunc('hour', e.recorded_at) + INTERVAL '1 hour',
        e.sensor_type_code
),
hourly_features AS (
    SELECT
        machine_id,
        prediction_time,
        SUM(readings_count) AS readings_count_1h,
        SUM(out_of_range_count) AS out_of_range_count_1h,

        AVG(average_value) FILTER (WHERE sensor_type_code = 'TEMPERATURE') AS temperature_avg_1h,
        MIN(minimum_value) FILTER (WHERE sensor_type_code = 'TEMPERATURE') AS temperature_min_1h,
        MAX(maximum_value) FILTER (WHERE sensor_type_code = 'TEMPERATURE') AS temperature_max_1h,
        AVG(standard_deviation) FILTER (WHERE sensor_type_code = 'TEMPERATURE') AS temperature_std_1h,
        SUM(out_of_range_count) FILTER (WHERE sensor_type_code = 'TEMPERATURE') AS temperature_out_of_range_1h,

        AVG(average_value) FILTER (WHERE sensor_type_code = 'VIBRATION') AS vibration_avg_1h,
        MIN(minimum_value) FILTER (WHERE sensor_type_code = 'VIBRATION') AS vibration_min_1h,
        MAX(maximum_value) FILTER (WHERE sensor_type_code = 'VIBRATION') AS vibration_max_1h,
        AVG(standard_deviation) FILTER (WHERE sensor_type_code = 'VIBRATION') AS vibration_std_1h,
        SUM(out_of_range_count) FILTER (WHERE sensor_type_code = 'VIBRATION') AS vibration_out_of_range_1h,

        AVG(average_value) FILTER (WHERE sensor_type_code = 'POWER') AS power_avg_1h,
        MIN(minimum_value) FILTER (WHERE sensor_type_code = 'POWER') AS power_min_1h,
        MAX(maximum_value) FILTER (WHERE sensor_type_code = 'POWER') AS power_max_1h,
        AVG(standard_deviation) FILTER (WHERE sensor_type_code = 'POWER') AS power_std_1h,

        AVG(average_value) FILTER (WHERE sensor_type_code = 'RPM') AS rpm_avg_1h,
        MIN(minimum_value) FILTER (WHERE sensor_type_code = 'RPM') AS rpm_min_1h,
        MAX(maximum_value) FILTER (WHERE sensor_type_code = 'RPM') AS rpm_max_1h,
        AVG(standard_deviation) FILTER (WHERE sensor_type_code = 'RPM') AS rpm_std_1h,

        AVG(average_value) FILTER (WHERE sensor_type_code = 'PRESSURE') AS pressure_avg_1h,
        MIN(minimum_value) FILTER (WHERE sensor_type_code = 'PRESSURE') AS pressure_min_1h,
        MAX(maximum_value) FILTER (WHERE sensor_type_code = 'PRESSURE') AS pressure_max_1h,
        AVG(standard_deviation) FILTER (WHERE sensor_type_code = 'PRESSURE') AS pressure_std_1h,

        AVG(average_value) FILTER (WHERE sensor_type_code = 'HUMIDITY') AS humidity_avg_1h,
        MIN(minimum_value) FILTER (WHERE sensor_type_code = 'HUMIDITY') AS humidity_min_1h,
        MAX(maximum_value) FILTER (WHERE sensor_type_code = 'HUMIDITY') AS humidity_max_1h,
        AVG(standard_deviation) FILTER (WHERE sensor_type_code = 'HUMIDITY') AS humidity_std_1h
    FROM sensor_hourly
    GROUP BY machine_id, prediction_time
),
observation_end AS (
    SELECT LEAST(
        (SELECT MAX(recorded_at) FROM public.sensor_readings),
        (SELECT MAX(started_at) FROM public.machine_events)
    ) AS last_observed_at
)
SELECT
    h.machine_id,
    m.machine_code,
    mt.type_code AS machine_type_code,
    m.line_id,
    h.prediction_time,
    ROUND(
        EXTRACT(EPOCH FROM (h.prediction_time - m.commissioned_at))
        / (365.25 * 24 * 60 * 60),
        3
    ) AS machine_age_years,
    mt.nominal_power_kw,

    h.readings_count_1h,
    h.out_of_range_count_1h,
    h.temperature_avg_1h,
    h.temperature_min_1h,
    h.temperature_max_1h,
    h.temperature_std_1h,
    COALESCE(h.temperature_out_of_range_1h, 0) AS temperature_out_of_range_1h,
    h.vibration_avg_1h,
    h.vibration_min_1h,
    h.vibration_max_1h,
    h.vibration_std_1h,
    COALESCE(h.vibration_out_of_range_1h, 0) AS vibration_out_of_range_1h,
    h.power_avg_1h,
    h.power_min_1h,
    h.power_max_1h,
    h.power_std_1h,
    h.rpm_avg_1h,
    h.rpm_min_1h,
    h.rpm_max_1h,
    h.rpm_std_1h,
    h.pressure_avg_1h,
    h.pressure_min_1h,
    h.pressure_max_1h,
    h.pressure_std_1h,
    h.humidity_avg_1h,
    h.humidity_min_1h,
    h.humidity_max_1h,
    h.humidity_std_1h,

    COALESCE(event_history.breakdowns_before, 0) AS breakdowns_before,
    event_history.hours_since_last_breakdown,
    COALESCE(maintenance_history.maintenance_last_30d, 0) AS maintenance_last_30d,
    maintenance_history.hours_since_last_maintenance,

    CASE
        WHEN EXISTS (
            SELECT 1
            FROM public.machine_events AS future_event
            JOIN public.machine_event_types AS future_type
                ON future_type.event_type_id = future_event.event_type_id
            WHERE future_event.machine_id = h.machine_id
              AND future_type.event_code = 'BREAKDOWN'
              AND future_event.started_at >= h.prediction_time
              AND future_event.started_at < h.prediction_time + INTERVAL '6 hours'
        ) THEN 1
        ELSE 0
    END AS failure_next_6h

FROM hourly_features AS h
JOIN public.machines AS m
    ON m.machine_id = h.machine_id
JOIN public.machine_types AS mt
    ON mt.machine_type_id = m.machine_type_id
CROSS JOIN observation_end AS oe

LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS breakdowns_before,
        ROUND(
            EXTRACT(EPOCH FROM (h.prediction_time - MAX(me.started_at))) / 3600.0,
            3
        ) AS hours_since_last_breakdown
    FROM public.machine_events AS me
    JOIN public.machine_event_types AS met
        ON met.event_type_id = me.event_type_id
    WHERE me.machine_id = h.machine_id
      AND met.event_code = 'BREAKDOWN'
      AND me.started_at < h.prediction_time
) AS event_history ON TRUE

LEFT JOIN LATERAL (
    SELECT
        COUNT(*) FILTER (
            WHERE COALESCE(mwo.completed_at, mwo.started_at, mwo.created_at)
                  >= h.prediction_time - INTERVAL '30 days'
        ) AS maintenance_last_30d,
        ROUND(
            EXTRACT(EPOCH FROM (
                h.prediction_time
                - MAX(COALESCE(mwo.completed_at, mwo.started_at, mwo.created_at))
            )) / 3600.0,
            3
        ) AS hours_since_last_maintenance
    FROM public.maintenance_work_orders AS mwo
    WHERE mwo.machine_id = h.machine_id
      AND COALESCE(mwo.completed_at, mwo.started_at, mwo.created_at) < h.prediction_time
) AS maintenance_history ON TRUE

WHERE h.prediction_time + INTERVAL '6 hours' <= oe.last_observed_at
  AND NOT EXISTS (
      SELECT 1
      FROM public.machine_events AS recent_event
      JOIN public.machine_event_types AS recent_type
          ON recent_type.event_type_id = recent_event.event_type_id
      WHERE recent_event.machine_id = h.machine_id
        AND recent_type.event_code = 'BREAKDOWN'
        AND recent_event.started_at >= h.prediction_time - INTERVAL '1 hour'
        AND recent_event.started_at < h.prediction_time
  );

COMMENT ON VIEW public.v_predictive_maintenance_ml IS
'Часовая ML-выборка: признаки из прошлого и цель BREAKDOWN в следующие 6 часов без использования будущих данных.';

-- 1. Проверка размера и баланса целевой переменной
SELECT
    COUNT(*) AS samples_count,
    COUNT(DISTINCT machine_id) AS machines_count,
    SUM(failure_next_6h) AS positive_samples,
    COUNT(*) - SUM(failure_next_6h) AS negative_samples,
    ROUND(100.0 * SUM(failure_next_6h) / COUNT(*), 4) AS positive_percent
FROM public.v_predictive_maintenance_ml;

-- 2. Проверка временного диапазона
SELECT
    MIN(prediction_time) AS first_prediction_time,
    MAX(prediction_time) AS last_prediction_time
FROM public.v_predictive_maintenance_ml;

-- 3. Проверка пропусков в основных признаках
SELECT
    COUNT(*) FILTER (WHERE temperature_avg_1h IS NULL) AS missing_temperature,
    COUNT(*) FILTER (WHERE vibration_avg_1h IS NULL) AS missing_vibration,
    COUNT(*) FILTER (WHERE power_avg_1h IS NULL) AS missing_power,
    COUNT(*) FILTER (WHERE rpm_avg_1h IS NULL) AS missing_rpm,
    COUNT(*) FILTER (WHERE pressure_avg_1h IS NULL) AS missing_pressure,
    COUNT(*) FILTER (WHERE humidity_avg_1h IS NULL) AS missing_humidity
FROM public.v_predictive_maintenance_ml;

-- 4. Контрольный просмотр строк
SELECT *
FROM public.v_predictive_maintenance_ml
ORDER BY prediction_time, machine_id
LIMIT 20;
