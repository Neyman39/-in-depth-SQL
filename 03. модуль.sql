SET search_path TO stud_novichenkov, pitanie, public;

-- Задание А1. Заказы 2025 г. с клиентом, регионом и менеджером
SELECT o.order_number,
       o.order_date,
       c.customer_name,
       COALESCE(r.region_name, '— регион не указан —') AS region_name,
       e.full_name                                     AS manager
FROM   orders    AS o
JOIN   customers AS c ON c.customer_id = o.customer_id
LEFT   JOIN regions   AS r ON r.region_id = c.region_id
JOIN   employees AS e ON e.employee_id = o.employee_id
WHERE  o.order_date >= DATE '2025-01-01'
  AND  o.order_date <  DATE '2026-01-01'
  AND  o.status <> 'Отменён'
ORDER  BY o.order_date, o.order_number;
-- Вывод: 2240 строк

-- Задание А2.1. Позиции со скидкой > 10% в 2025 г. с руководителем
SELECT o.order_number,
       o.order_date,
       e.full_name    AS manager,
       COALESCE(m.full_name, '— (высшее руководство)') AS manager_manager,
       p.product_name,
       oi.quantity,
       oi.unit_price,
       oi.discount_pct
FROM   order_items AS oi
JOIN   orders      AS o ON o.order_id   = oi.order_id
JOIN   employees   AS e ON e.employee_id = o.employee_id
LEFT   JOIN employees AS m ON m.employee_id = e.manager_id
JOIN   products    AS p ON p.product_id = oi.product_id
WHERE  o.order_date >= DATE '2025-01-01'
  AND  o.order_date <  DATE '2026-01-01'
  AND  o.status <> 'Отменён'
  AND  oi.discount_pct > 10
ORDER  BY o.order_date, o.order_number;
-- Вывод: 2088 строк

-- Задание А2.2. Сколько таких позиций по каждому менеджеру
SELECT e.full_name    AS manager,
       COALESCE(m.full_name, '— (высшее руководство)') AS manager_manager,
       COUNT(*)       AS over_policy_items
FROM   order_items AS oi
JOIN   orders      AS o ON o.order_id   = oi.order_id
JOIN   employees   AS e ON e.employee_id = o.employee_id
LEFT   JOIN employees AS m ON m.employee_id = e.manager_id
WHERE  o.status <> 'Отменён'
  AND  oi.discount_pct > 10
GROUP  BY e.full_name, m.full_name
ORDER  BY over_policy_items DESC;
-- Менеджер                 | Руководитель            | кол-во нарущений
-------------------------------------------------------------------------
-- Соколов Игорь Андреевич  | Ершова Татьяна Юрьевна  | 4167
-- Попов Станислав Игоревич	| Ершова Татьяна Юрьевна  |	53

-- Задание А3. Заказы, где оформивший менеджер ≠ закреплённого
SELECT o.order_number,
       o.order_date,
       c.customer_name,
       e1.full_name AS order_manager,       -- кто оформил
       e2.full_name AS assigned_manager     -- кто закреплён
FROM   orders    AS o
JOIN   customers AS c  ON c.customer_id = o.customer_id
JOIN   employees AS e1 ON e1.employee_id = o.employee_id
JOIN   employees AS e2 ON e2.employee_id = c.manager_id
WHERE  o.employee_id <> c.manager_id
  AND  o.status <> 'Отменён'
ORDER  BY o.order_date;
-- Проверка: 35 строк


-- Задание А4.1. Счета без единой оплаты
SELECT i.invoice_number,
       i.invoice_date,
       i.due_date,
       i.amount,
       c.customer_name,
       e.full_name AS assigned_manager
FROM   invoices  AS i
JOIN   orders    AS o ON o.order_id    = i.order_id
JOIN   customers AS c ON c.customer_id = o.customer_id
JOIN   employees AS e ON e.employee_id = c.manager_id
LEFT   JOIN payments AS p ON p.invoice_id = i.invoice_id
WHERE  p.payment_id IS NULL
ORDER  BY i.amount DESC;
-- Вывод: 229 счетов

-- Задание А4.2. Сколько из них просрочены на 31.12.2025 и на какую сумму
SELECT COUNT(*)     AS overdue_cnt,
       ROUND(SUM(i.amount), 2) AS overdue_sum
FROM   invoices AS i
LEFT   JOIN payments AS p ON p.invoice_id = i.invoice_id
WHERE  p.payment_id IS NULL
  AND  i.due_date < DATE '2026-01-01';
-- Вывод: 60 счетов на 10 699 261,89 руб.

-- Задание А5.1. Группировка неоплаченных счетов по клиенту
SELECT c.customer_id,
       c.customer_name,
       c.credit_limit,
       COUNT(*)       AS unpaid_invoices,
       ROUND(SUM(i.amount), 2) AS unpaid_sum
FROM   invoices  AS i
JOIN   orders    AS o ON o.order_id    = i.order_id
JOIN   customers AS c ON c.customer_id = o.customer_id
LEFT   JOIN payments AS p ON p.invoice_id = i.invoice_id
WHERE  p.payment_id IS NULL
GROUP  BY c.customer_id, c.customer_name, c.credit_limit
ORDER  BY unpaid_sum DESC
LIMIT  10;
-- Лидер неоплаченных счетов: клиент с id 1 (ООО "Торговый дом Вектор"), 31 неоплаченный счёт

-- Задание А5.2. Полный долг клиента-лидера (сумма счетов - сумма оплат)
-- Шаг 1: сумма всех счетов
SELECT ROUND(SUM(i.amount), 2) AS total_invoiced
FROM   invoices AS i
JOIN   orders   AS o ON o.order_id = i.order_id
WHERE  o.customer_id = 1;
-- 14 716 047,93

-- Шаг 2: сумма всех оплат
SELECT ROUND(SUM(p.amount), 2) AS total_paid
FROM   payments AS p
JOIN   invoices AS i ON i.invoice_id = p.invoice_id
JOIN   orders   AS o ON o.order_id   = i.order_id
WHERE  o.customer_id = 1;
-- 7 808 447,48

-- Итоговый долг: 14 716 047,93 - 7 808 447,48 = 6 907 600,45 руб.
-- Кредитный лимит: 3 000 000 руб.
-- Превышение: в 2,3 раза!

-- Задание А5.3. Неоплаченные счета клиента-лидера и продолжались ли отгрузки
SELECT i.invoice_number,
       i.invoice_date,
       i.due_date,
       i.amount,
       o.shipped_date,
       CASE WHEN o.shipped_date > i.due_date THEN 'отгружено ПОСЛЕ просрочки'
            ELSE '' END AS flag
FROM   invoices AS i
JOIN   orders   AS o ON o.order_id = i.order_id
LEFT   JOIN payments AS p ON p.invoice_id = i.invoice_id
WHERE  o.customer_id = 1
  AND  p.payment_id IS NULL
ORDER  BY i.due_date;
-- Вывод: 31 неоплаченный счёт; отгрузки продолжались даже после просрочки

-- Задание А7.1. Все клиенты и их декабрьские заказы
SELECT c.customer_id,
       c.customer_name,
       o.order_number,
       o.order_date
FROM   customers AS c
LEFT   JOIN orders AS o
       ON  o.customer_id = c.customer_id
       AND o.order_date >= DATE '2025-12-01'
       AND o.order_date <  DATE '2026-01-01'
ORDER  BY c.customer_id, o.order_date;
-- Вывод: 228 строк, 73 клиента

-- Задание А7.2. Только «замолчавшие» клиенты
SELECT c.customer_id,
       c.customer_name,
       c.customer_type
FROM   customers AS c
LEFT   JOIN orders AS o
       ON  o.customer_id = c.customer_id
       AND o.order_date >= DATE '2025-12-01'
       AND o.order_date <  DATE '2026-01-01'
WHERE  o.order_id IS NULL
ORDER  BY c.customer_name;
-- Вывод: 10 клиентов