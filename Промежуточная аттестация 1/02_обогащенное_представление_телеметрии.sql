/*
  ПРОЕКТ: Предиктивное обслуживание промышленного оборудования
  ШАГ 02: Создание обогащённого представления телеметрии

  Зависимость: сначала выполнить 01_аудит_базы.sql.

  Представление объединяет показания сенсоров с характеристиками
  сенсора, машины и типа оборудования. Исходные таблицы не изменяются.
*/

CREATE OR REPLACE VIEW public.v_sensor_readings_enriched AS
SELECT
    sr.reading_id,
    sr.recorded_at,
    sr.numeric_value,
    sr.quality_status,

    s.sensor_id,
    s.sensor_code,
    s.machine_id,
    s.sampling_interval_seconds,

    m.machine_code,
    m.machine_name,
    m.line_id,
    m.commissioned_at,
    m.status AS machine_status,

    mt.machine_type_id,
    mt.type_code AS machine_type_code,
    mt.type_name AS machine_type_name,
    mt.manufacturer,
    mt.model,
    mt.nominal_power_kw,

    st.sensor_type_id,
    st.type_code AS sensor_type_code,
    st.type_name AS sensor_type_name,
    st.measurement_unit,
    st.min_valid_value,
    st.max_valid_value,

    CASE
        WHEN sr.numeric_value < st.min_valid_value
          OR sr.numeric_value > st.max_valid_value
        THEN 1
        ELSE 0
    END AS is_out_of_range

FROM public.sensor_readings AS sr
JOIN public.sensors AS s
    ON s.sensor_id = sr.sensor_id
JOIN public.sensor_types AS st
    ON st.sensor_type_id = s.sensor_type_id
JOIN public.machines AS m
    ON m.machine_id = s.machine_id
JOIN public.machine_types AS mt
    ON mt.machine_type_id = m.machine_type_id;

COMMENT ON VIEW public.v_sensor_readings_enriched IS
'Показания IoT-сенсоров, дополненные характеристиками сенсоров и оборудования и признаком выхода за допустимый диапазон.';

-- 1. Представление должно содержать столько же строк, сколько sensor_readings
SELECT COUNT(*) AS enriched_rows
FROM public.v_sensor_readings_enriched;

-- 2. Контрольный просмотр первых строк
SELECT *
FROM public.v_sensor_readings_enriched
ORDER BY recorded_at, reading_id
LIMIT 20;

-- 3. Сводка по типам сенсоров
SELECT
    sensor_type_code,
    measurement_unit,
    COUNT(*) AS readings_count,
    COUNT(DISTINCT machine_id) AS machines_count,
    ROUND(AVG(numeric_value), 3) AS average_value,
    ROUND(MIN(numeric_value), 3) AS minimum_value,
    ROUND(MAX(numeric_value), 3) AS maximum_value,
    SUM(is_out_of_range) AS out_of_range_count,
    ROUND(100.0 * SUM(is_out_of_range) / COUNT(*), 4) AS out_of_range_percent
FROM public.v_sensor_readings_enriched
GROUP BY sensor_type_code, measurement_unit
ORDER BY sensor_type_code;

