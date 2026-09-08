/*
  ПРОЕКТ: Предиктивное обслуживание промышленного оборудования
  ШАГ 01: Проверка восстановленной базы manufacturing

  Порядок выполнения:
  1. Открыть Query Tool именно для базы manufacturing.
  2. Выполнить файл целиком (F5).
  3. Сохранить результаты запросов для отчёта.

  Скрипт только читает данные и ничего не изменяет.
*/

-- 1. Проверка подключения и версии PostgreSQL
SELECT
    current_database() AS database_name,
    current_user AS database_user,
    version() AS postgresql_version;

-- 2. Количество пользовательских таблиц в схеме public
SELECT COUNT(*) AS public_tables_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';

-- 3. Размеры основных таблиц проекта
SELECT
    (SELECT COUNT(*) FROM machines) AS machines,
    (SELECT COUNT(*) FROM sensors) AS sensors,
    (SELECT COUNT(*) FROM sensor_readings) AS sensor_readings,
    (SELECT COUNT(*) FROM machine_events) AS machine_events,
    (SELECT COUNT(*) FROM maintenance_work_orders) AS maintenance_orders,
    (SELECT COUNT(*) FROM production_operations) AS production_operations;

-- 4. Временной охват телеметрии
SELECT
    MIN(recorded_at) AS readings_from,
    MAX(recorded_at) AS readings_to,
    MAX(recorded_at) - MIN(recorded_at) AS observation_period
FROM sensor_readings;

-- 5. Типы сенсоров, объём данных и выходы за допустимые границы
SELECT
    st.type_code AS sensor_type,
    st.measurement_unit,
    COUNT(*) AS readings_count,
    COUNT(DISTINCT s.machine_id) AS machines_count,
    ROUND(AVG(sr.numeric_value), 3) AS average_value,
    ROUND(MIN(sr.numeric_value), 3) AS minimum_value,
    ROUND(MAX(sr.numeric_value), 3) AS maximum_value,
    COUNT(*) FILTER (
        WHERE sr.numeric_value < st.min_valid_value
           OR sr.numeric_value > st.max_valid_value
    ) AS out_of_range_count
FROM sensor_readings AS sr
JOIN sensors AS s
    ON s.sensor_id = sr.sensor_id
JOIN sensor_types AS st
    ON st.sensor_type_id = s.sensor_type_id
GROUP BY
    st.type_code,
    st.measurement_unit
ORDER BY st.type_code;

-- 6. Фактическое количество событий каждого типа
SELECT
    met.event_code,
    met.event_name,
    met.event_category,
    COUNT(me.machine_event_id) AS events_count,
    COUNT(DISTINCT me.machine_id) AS affected_machines
FROM machine_event_types AS met
LEFT JOIN machine_events AS me
    ON me.event_type_id = met.event_type_id
GROUP BY
    met.event_type_id,
    met.event_code,
    met.event_name,
    met.event_category
ORDER BY events_count DESC, met.event_code;

-- 7. Проверка целевого события BREAKDOWN
SELECT
    COUNT(*) AS breakdowns_count,
    COUNT(DISTINCT me.machine_id) AS machines_with_breakdowns,
    MIN(me.started_at) AS first_breakdown,
    MAX(me.started_at) AS last_breakdown
FROM machine_events AS me
JOIN machine_event_types AS met
    ON met.event_type_id = me.event_type_id
WHERE met.event_code = 'BREAKDOWN';

-- 8. Распределение поломок по степени серьёзности
SELECT
    COALESCE(me.severity, 'NOT_SPECIFIED') AS severity,
    COUNT(*) AS breakdowns_count
FROM machine_events AS me
JOIN machine_event_types AS met
    ON met.event_type_id = me.event_type_id
WHERE met.event_code = 'BREAKDOWN'
GROUP BY COALESCE(me.severity, 'NOT_SPECIFIED')
ORDER BY breakdowns_count DESC;

-- 9. Проверка качества телеметрии
SELECT
    quality_status,
    COUNT(*) AS readings_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS share_percent
FROM sensor_readings
GROUP BY quality_status
ORDER BY readings_count DESC;

-- 10. Проверка пропусков в ключевых полях
SELECT
    COUNT(*) FILTER (WHERE sensor_id IS NULL) AS missing_sensor_id,
    COUNT(*) FILTER (WHERE recorded_at IS NULL) AS missing_recorded_at,
    COUNT(*) FILTER (WHERE numeric_value IS NULL) AS missing_numeric_value,
    COUNT(*) FILTER (WHERE quality_status IS NULL) AS missing_quality_status
FROM sensor_readings;

