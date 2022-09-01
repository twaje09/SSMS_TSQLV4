/*Data exploration and querying practice 
		using TSQLV4 database from the book T-SQL Fundamentals by Ben-Gan Itzik */

/* Tables (not complete list) include:
dbo.Orders
Hr.Employees
Production.Categories
Products.Products
Productions.Suppliers
Sales.Customers
Sales.OrderDetails
Sales.Orders
and others
*/


USE TSQLV4;

--select top 10 rows for Sales.Orders
SELECT TOP 10 *
FROM Sales.Orders;

--return duplicate rows from Sales.Orders, order by orderdate
SELECT TOP 5 WITH TIES orderid, orderdate, custid,empid
FROM Sales.Orders
ORDER BY orderdate DESC;

--offset (skip) 50 rows, then fetch (filter) next 25
SELECT orderid, orderdate, custid, empid
FROM Sales.Orders
ORDER BY orderdate, orderid
OFFSET 50 ROWS FETCH NEXT 25 ROWS ONLY;

--add row number for each window (by custid), ordered by orderdate
SELECT orderid, custid, orderdate,
	ROW_NUMBER() OVER(PARTITION BY custid
	ORDER BY orderdate) AS rownum
FROM Sales.Orders
ORDER BY custid, orderdate;


--find orders based on filtered IDs
SELECT orderid, empid, orderdate
FROM Sales.Orders
WHERE orderid IN (10248,10249,12050);

--find orders based on range of IDs
SELECT orderid, empid, orderdate
FROM Sales.Orders
WHERE orderid BETWEEN 10300 AND 10310;

--find employees w/ last name starting with 'D'
SELECT empid,firstname, lastname
FROM HR.Employees
WHERE lastname LIKE 'D%';

--assign categories based on on categoryid
SELECT productid,productname,categoryid,
	CASE categoryid
		WHEN 1 THEN 'Beverages'
		WHEN 2 THEN 'Condiments'
		WHEN 3 THEN 'Confections'
		WHEN 4 THEN 'Dairy Products'
		WHEN 5 THEN 'Grains/Cereals'
		WHEN 6 THEN 'Meat/Poultry'
		WHEN 7 THEN 'Produce'
		WHEN 8 THEN 'Seafood'
		ELSE 'Unknown Category'
	END AS categoryname
FROM Production.Products;

--concatenation using + for employee first names and last names
SELECT empid, firstname + ' ' + lastname AS fullname
FROM HR.Employees;

--concatenation using CONCAT function. New 'location' column includes country, region, city.
SELECT custid, country, region, city,
	CONCAT(country, ',' + region,',' + city) AS location
FROM Sales.Customers;


--Find # occurences of 'e' in lastname using LEN and REPLACE
SELECT empid, lastname, LEN(lastname) - LEN(REPLACE(lastname,'e','')) AS numoccur
FROM HR.Employees;

--separate into separate strings by ',' . Cast as INT. Returns separate value in a column
SELECT CAST(value AS INT) AS myvalue
FROM
STRING_SPLIT('10248,10249,10250',',') AS S;

--return region, sort NULLs last
SELECT custid, region
FROM Sales.Customers
ORDER BY
	CASE WHEN region IS NULL THEN 1
	ELSE 0 END, region;


--use cross join to produce a result set with a sequence of integers 
DROP TABLE if exists dbo.Digits;
CREATE TABLE dbo.Digits (digit INT NOT NULL PRIMARY Key);
INSERT INTO dbo.Digits (digit) VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);
SELECT digit FROM dbo.Digits;

--create sequence of numbers 1 to 1000. apply cross joins to 3 instances of Digits, each representing a power of 10
SELECT D3.digit * 100 + D2.digit * 10 + D1.digit + 1 AS n
FROM			dbo.Digits AS D1
	CROSS JOIN	dbo.Digits AS D2
	CROSS JOIN	dbo.Digits AS D3
ORDER BY n;



--audit updates to column values against OrderDetails table. create custom table Sales.OrderDetailsAudit:
USE TSQLV4;
DROP TABLE IF EXISTS Sales.OrderDetailsAudit;
CREATE TABLE Sales.OrderDetailsAudit (
	lsn				INT	NOT NULL	Identity,
	orderid			INT NOT NULL,
	productid		INT NOT NULL,
	dt				DATETIME NOT NULL,
	loginname		sysname NOT NULL,
	columnname		sysname NOT NULL,
	oldval			SQL_VARIANT,
	newval			SQL_VARIANT,
	CONSTRAINT PK_OrderDetailsAudit
	PRIMARY KEY(lsn),
	CONSTRAINT FK_OrderDetailsAudit_OrderDetails
	FOREIGN KEY(orderid, productid)
	REFERENCES Sales.OrderDetails(orderid,productid)
	);

--write query against OrderDetails and OrderDetails Audit tables that returns info about all value changes that took place in column qty.
--for each row, return current value from OrderDetails table and values before and after the change from OrderDetailsAudit
--join the 2 tables on a PK-FK relationship..

SELECT OD.orderid, OD.productid, OD.qty, ODA.dt,
	ODA.loginname, ODA.oldval, ODA.newval
FROM Sales.OrderDetails AS OD
	INNER JOIN Sales.OrderDetailsAudit AS ODA
	ON OD.orderid = ODA.orderid
	AND OD.productid = ODA.productid
WHERE ODA.columnname = N'qty';


--LEFT OUTER JOIN. below includes customers who didn't place any orders:
SELECT C.custid, C.companyname, O.orderid
FROM Sales.Customers AS C
	LEFT OUTER JOIN Sales.Orders AS O
		ON C.custid = O.custid;
--ids 22 and 57 did not have orders but were added as OUTER rows

--Same as above but filter to only return NULLs
SELECT C.custid, C.companyname, O.orderid
FROM Sales.Customers AS C
	LEFT OUTER JOIN Sales.Orders AS O
		ON C.custid = O.custid
WHERE orderid IS NULL;



-----------------------------------------------------------------------
/*return all Orders from Orders table, and show at least one row from range 1/1/14 to 12/31/16.
First write query getting sequence of all dates in the requested period. Then left outer join between that and Orders table. */
--table dbo.Nums has one column 'n' with integers 1 - 100
--use dbo.Nums to produce sequence of dates in that range
--query the dbo.Nums table and filter as many numbers as the number of days in the requested date range using DATEDIFF, n-1 to starting point
SELECT DATEADD(day, n-1, CAST('20140101' AS DATE)) AS orderdate
FROM dbo.Nums
WHERE n <= DATEDIFF(day, '20140101', '20161231') + 1
ORDER BY orderdate;

--now left outer join dbo.Nums and Sales.Orders ON above query
SELECT DATEADD(day, Nums.n - 1, CAST('20140101' AS DATE)) AS orderdate,
	O.orderid, O.custid, O.empid
FROM dbo.Nums
	LEFT OUTER JOIN Sales.Orders AS O
		ON DATEADD(day, Nums.n - 1, CAST('20140101' AS DATE)) = O.orderdate
WHERE Nums.n <= DATEDIFF(day,'20140101', '20161231') + 1
ORDER BY orderdate;
--NULLs will show for ID columns on dates no order was made
-----------------------------------------------------------------------

--multiple join query, including an outer join without losing the outer rows
--inner join between Orders and OrderDetails, then join results with Customers using right Outer join
SELECT C.custid, O.orderid, OD.productid, OD.qty
FROM Sales.Orders AS O
	INNER JOIN Sales.OrderDetails AS OD
		ON O.orderid = OD.orderid
	RIGHT OUTER JOIN Sales.Customers AS C
		ON O.custid = C.custid;

--multiple join query, including an outer join without losing the outer rows
--parentheses around Order and OrderDetails to create independent unit, then Outer Join
SELECT C.custid, O.orderid, OD.productid, OD.qty
FROM Sales.Customers AS C
	LEFT OUTER JOIN
		(Sales.Orders AS O
			INNER JOIN Sales.OrderDetails AS OD
				ON O.orderid = OD.orderid)
			ON C.custid = O.custid;

--filter only orders on 2/12/2016, but show all customers. to do so, must include extra filter in ON clause
SELECT C.custid, C.companyname, O.orderid, O.orderdate
FROM Sales.Customers AS C
	LEFT OUTER JOIN Sales.Orders AS O
		ON O.custid = C.custid
		AND O.orderdate = '20160212';


--query Orders and return max order value. store it in a variable.
DECLARE @maxid AS INT = (SELECT MAX(orderid)
FROM
Sales.Orders);
SELECT orderid, orderdate, empid,custid
FROM Sales.Orders
WHERE orderid = @maxid;


------------------------------------------------------------------------------------------
--MULTIPLE subqueries..
--First create new table dbo.Orders
DROP TABLE IF EXISTS dbo.Orders;
CREATE TABLE dbo.Orders (
	orderid INT NOT NULL
	CONSTRAINT PK_Orders PRIMARY KEY);
INSERT INTO dbo.Orders (orderid)
	SELECT orderid
	FROM Sales.Orders
	WHERE orderid % 2 = 0;

--write query that returns all inidivdual order IDS missing between the min and max ones in the table
--Use dbo.Nums table
SELECT n
FROM dbo.Nums
WHERE n BETWEEN 
		(SELECT MIN(O.orderid) FROM dbo.Orders AS O)
	AND (SELECT MAX(O.orderid) FROM dbo.Orders AS O)
	AND n NOT IN (SELECT O.orderid FROM dbo.Orders AS O);
--returned all missing (odd #) orders

DROP TABLE IF EXISTS dbo.Orders;
------------------------------------------------------------------------------------------


--filter orders where orderID is equal to value returned by subquery
--for each row in O1, the subquery returns the max orderID for the current customer. Outer custid and subquery custid match.
SELECT custid, orderid, orderdate, empid
FROM Sales.Orders AS O1
WHERE orderid =
	(SELECT MAX(O2.orderid)
	FROM Sales.Orders AS O2
	WHERE O2.custid = O1.custid);


--Include percentage of each customer's total order using correlated subquery:
SELECT orderid, custid, val, CAST(100. * val / (SELECT SUM (O2.val)
FROM Sales.OrderValues AS O2
WHERE O2.custid = O1.custid)
	AS NUMERIC(5,2)) AS pct
	FROM Sales.OrderValues AS O1
	ORDER BY custid, orderid;


--use EXISTS predicate to return customers from Spain if they show up in the Orders table
SELECT custid, companyname
FROM Sales.Customers AS C
WHERE country = N'Spain'
	AND EXISTS
	(SELECT * FROM Sales.Orders AS O
	WHERE O.custid = C.custid);


--for each order, return info about the current order and the previous orderid. "Max value that is smaller than the current value"
SELECT orderid, orderdate, empid, custid,
	(SELECT MAX(O2.orderid)
	FROM Sales.Orders AS O2
	WHERE O2.orderid < O1.orderid) AS previousorderid
FROM Sales.Orders AS O1;
--because there's no order before the 1st order, subquery returned a NULL. 
--could also have worked by building it as "min value that is greater than the current value."
--could also use window functions LAG or LEAD


--create running total of total orders each year. use a correlated subquery against a 2nd instance of the view Sales.OrderTotalsByYear.
--subquery should filter all rows in O2 where the order year is <= to current year in O1, and sum quantities from O2
SELECT orderyear, qty,
	(SELECT SUM(O2.qty)
	FROM Sales.OrderTotalsByYear AS O2
	WHERE O2.orderyear <= O1.orderyear) AS runqty
FROM Sales.OrderTotalsByYear AS O1
ORDER BY orderyear;
--could also use window functions to calculate


--returns all orders placed by the customer(s) who placed the highest number of orders
SELECT custid, orderid, orderdate, empid
FROM Sales.Orders
WHERE custid IN 
				(SELECT TOP (1) WITH TIES O.custid
				FROM Sales.Orders AS O
				GROUP BY O.custid
				ORDER BY COUNT(*) DESC);

--return employees who did not place an order on or after 5/1/2016
SELECT empid,FirstName,lastname
FROM HR.Employees as E
WHERE empid NOT IN
			(SELECT empid 
			FROM Sales.Orders
			WHERE orderdate >= '20160501'
			AND orderdate IS NOT NULL);


--return custid, company for customers who ordered product #12
SELECT custid, companyname
FROM Sales.Customers AS C
WHERE EXISTS 
	(SELECT *
	FROM Sales.Orders AS O
	WHERE O.custid = C.custid
		AND EXISTS 
			(SELECT * 
			FROM Sales.OrderDetails AS OD
			WHERE OD.orderid = O.orderid
				AND OD.ProductID = 12));


--check growth of distinct customers by year.
--use CTE. CTEs allow multiple instances of the same CTE. Create instances Cur and Prv below.
--calculate "growth" as the difference of distinct customers in the current year and the previous year.
WITH YearlyCount AS
(
	SELECT YEAR(orderdate) AS orderyear, COUNT(DISTINCT custid) AS numcusts
	FROM Sales.Orders
	GROUP BY YEAR(orderdate)
)
SELECT Cur.orderyear, Cur.numcusts AS curnumcusts, Prv.numcusts AS prvnumcusts,
		Cur.numcusts - Prv.numcusts AS growth
		FROM YearlyCount AS Cur
			LEFT OUTER JOIN YearlyCount AS Prv
			ON Cur.orderyear = Prv.orderyear + 1;


--use CROSS APPLY to return the 3 most recent orders from each customers (TOP (3)). Customers with no order are excluded.
SELECT C.custid, A.orderid, A.orderdate
FROM Sales.Customers AS C
	CROSS APPLY
	(SELECT TOP (3) orderid, empid, orderdate, requireddate
	FROM Sales.Orders AS O
	WHERE O.custid = C.custid
	ORDER BY orderdate DESC, orderid DESC) AS A;

