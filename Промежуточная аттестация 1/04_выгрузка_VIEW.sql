/*
  ПРОЕКТ: Предиктивное обслуживание промышленного оборудования
  ШАГ 04: Выгрузка итогового VIEW в CSV

  Зависимость: сначала выполнить 03_итоговое_VIEW_для_ML.sql.

  Этот файл не изменяет базу. Запрос выводит готовую таблицу,
  которую нужно сохранить из pgAdmin 4 в CSV.
*/

-- 1. Контроль перед выгрузкой
SELECT
    COUNT(*) AS samples_count,
    COUNT(DISTINCT machine_id) AS machines_count,
    SUM(failure_next_6h) AS positive_samples
FROM public.v_predictive_maintenance_ml;

-- 2. Итоговый запрос для экспорта
-- Выполните только этот SELECT, затем в панели Data Output нажмите
-- кнопку сохранения результата и выберите формат CSV.
SELECT *
FROM public.v_predictive_maintenance_ml
ORDER BY prediction_time, machine_id;

/*
  Имя файла:
  manufacturing_ml_dataset.csv

*/
