use take_home;

create table take_home.position_dedup(
    user_id int,
    position_id int,
    company_id int,
    title varchar(50),
    mapped_role varchar(20),
    msa varchar(20),
    startdate varchar(20),
    enddate varchar(20)
);

drop table take_home.education_dedup;

create table take_home.education_dedup(
    user_id int,
    school varchar(60),
    degree varchar(60),
    startdate varchar(60),
    enddate varchar(60)
);

create table take_home.predicted_salaries(
    company_id int,
    mapped_role varchar(30),
    msa varchar(30),
    year varchar(30), /* assuming year to be not int */
    salary float
);

create table take_home.scaling_weights(
    mapped_role varchar(30),
    weight float
);

create table take_home.company_ref(
    company_id int,
    name varchar(30),
    website varchar(30),
    isin varchar(30)
);

insert into take_home.position_dedup
values
(1,1235,3,'Real Estate Salesperson', 'Salesperson', 'New York, NY', '2014-06', '2020-08'),
(1,1236,1,'Pharmaceutical Sales Rep', 'Salesperson', 'Ann Arbor, MI', '2018-06', NULL),
(2,2356,4,'Software Engineer', 'Software Engineer', 'San Francisco, CA', '2019-05', '2019-12'),
(2,2356,6,'Software Engineer II', 'Software Engineer', 'San Francisco, CA', '2020-05', NULL);

insert into take_home.education_dedup
values
(1, 'Sunnyside High School', 'High School', '2010-09', '2014-06'),
(2, 'Stanford University', 'Bachelor', '2014-09', '2018-05'),
(2, 'Columbia University', 'Master', '2018-09', '2020-05');

insert into take_home.predicted_salaries
values
(2, 'Salesperson', 'San Diego, CA', '2014', 124537.18),
(3, 'Software Engineer', 'Bachelor', '2009', 129415.74);

insert into take_home.scaling_weights
values
('Software Engineer', 1.11),
('Truck Driver', 10.00),
('Teacher', 2.15);

insert into take_home.company_ref
values
(1, 'Revilio Labs', 'reveliolabs.com', NULL),
(2, 'Apple', 'apple.com', 'US0378331005'),
(3, 'Netflix', 'netflix.com', 'US64110L1061');

create table take_home.client_requested_companies(
    name varchar(30)
);

insert into take_home.client_requested_companies
values
('Apple'),
('Amazon'),
('Netflix');


set @start = '2022-05-01';
set @end = CURRENT_DATE();

with recursive
months (date)
AS
(
    SELECT @start
    UNION ALL
    SELECT DATE_ADD(date, INTERVAL 1 Month)
    from months
    where DATE_ADD(date, INTERVAL 1 Month) < @end
)
select     MONTHNAME(date) as Month,
           YEAR(date) as Year
from months;

SELECT STR_TO_DATE('01,5,2013','%d,%m,%Y');

select STR_TO_DATE(startdate,'%Y-%m')
from take_home.position_dedup;

# drop table take_home.position_dedup;
drop table position_dedup_mnth;

drop table position_dedup_mnth_name;

#code to blow up start date and end date values to months and add all rows
CREATE TEMPORARY TABLE position_dedup_mnth
with recursive
months (date)
AS
(
    SELECT min(STR_TO_DATE(CONCAT(startdate,'-1'),'%Y-%m-%d')) from take_home.position_dedup
    UNION ALL
    SELECT date + INTERVAL 1 Month
    from months
    where date + INTERVAL 1 Month <= (select
                                        case
                                            when (select count(*)
                                        from take_home.position_dedup
                                        where enddate is null) > 0 then CURRENT_DATE()
                                            else
                                        (SELECT max(STR_TO_DATE(CONCAT(enddate,'-1'),'%Y-%m-%d'))
                                            from take_home.position_dedup)
                                        end)
)
select     b.*,
           MONTHNAME(date) as Month,
           YEAR(date) as Year,
           date as date
from months as a, take_home.position_dedup as b
where a.date >= STR_TO_DATE(CONCAT(b.startdate,'-1'),'%Y-%m-%d')
and a.date <= (select
                    case
                        when b.enddate is null then current_date()
                        else STR_TO_DATE(CONCAT(b.enddate,'-1'),'%Y-%m-%d')
                    end
               );

#check the output
select * from
position_dedup_mnth;

#index the companies that have been provided by the client
CREATE TEMPORARY TABLE position_dedup_mnth_name
select a.name,b.*
from
    (select company_id,name
    from take_home.client_requested_companies natural join take_home.company_ref) a,
    position_dedup_mnth b
where a.company_id = b.company_id;

#checking the output
select * from position_dedup_mnth_name;

#find the company id associated with a company name
# select company_id,name
# from take_home.client_requested_companies natural join take_home.company_ref;

#
# (SELECT min(STR_TO_DATE(startdate,'%Y-%m'))
#     from take_home.position_dedup);
#
# (SELECT max(STR_TO_DATE(enddate,'%Y-%m'))
#     from take_home.position_dedup);

# select
# case
#     when (select count(*)
# from take_home.position_dedup
# where enddate is null) > 0 then CURRENT_DATE()
#     else
# (SELECT max(STR_TO_DATE(enddate,'%Y-%m'))
#     from take_home.position_dedup)
# end


# select CONCAT('1 ','August 2020');
#
#
# select * from take_home.client_requested_companies;
#
# insert into take_home.scaling_weights
# values
#     ('Salesperson', 3);
#
# insert into take_home.predicted_salaries
# values
#     (3,'Salesperson', 'New York, NY', 2015, 123456),
#     (1,'Salesperson', 'Ann Arbor, MI', 2019, 123456);

#joining with predicted salary tables to get the salaries for the mapped roles
CREATE TEMPORARY TABLE before_scaling
select name, a.msa, Month, a.Year, salary, a.mapped_role
from take_home.predicted_salaries a,position_dedup_mnth_name b
where a.company_id = b.company_id and a.mapped_role = b.mapped_role and a.msa = b.msa and a.year = b.Year;

#checking the output
select * from before_scaling;

#joining the above table with scaling weights to finally calculate weighted average salary
CREATE TABLE Task1_Result
select name, msa, Month, Year, sum(salary*weight)/sum(weight) as average_salary
from before_scaling natural join take_home.scaling_weights
group by name, msa, Month, Year
order by name,Year;

# select * from take_home.position_dedup;
#
# select * from take_home.company_ref;
#
# insert into take_home.position_dedup values (2, 1236, 3, 'Software Engineer', 'Software Engineer', 'New York, NY', '2014-06', '2020-08');
#
#
# select *
# from take_home.predicted_salaries
#
# insert into take_home.predicted_salaries
# values
# (3,'Software Engineer', 'New York, NY', '2014', 120000),
# (3,'Software Engineer', 'New York, NY', '2015', 120000);
#
# select * from take_home.position_dedup;
#
# select * from take_home.scaling_weights


#### TASK 2 #####



insert into take_home.education_dedup
values (1, 'Sunnyside High School', 'High School', '2010-09', '2014-06'),
       (1, 'Stanford University', 'Bachelor', '2014-09', '2018-05'),
       (2, 'Columbia University', 'Master', '2018-09', '2020-05');


#checking if employee is working and attending school or not


#getting months for the education history of people
select * from education_dedup_mnth;

CREATE TEMPORARY TABLE education_dedup_mnth
with recursive
months (date)
AS
(
    SELECT min(STR_TO_DATE(CONCAT(startdate,'-1'),'%Y-%m-%d')) from take_home.education_dedup
    UNION ALL
    SELECT date + INTERVAL 1 Month
    from months
    where date + INTERVAL 1 Month <= (select
                                        case
                                            when (select count(*)
                                        from take_home.education_dedup
                                        where enddate is null) > 0 then CURRENT_DATE()
                                            else
                                        (SELECT max(STR_TO_DATE(CONCAT(enddate,'-1'),'%Y-%m-%d'))
                                            from take_home.education_dedup)
                                        end)
)
select     b.*,
           MONTHNAME(date) as Month,
           YEAR(date) as Year,
           date as date
from months as a, take_home.education_dedup as b
where a.date >= STR_TO_DATE(CONCAT(b.startdate,'-1'),'%Y-%m-%d')
and a.date <= (select
                    case
                        when b.enddate is null then current_date()
                        else STR_TO_DATE(CONCAT(b.enddate,'-1'),'%Y-%m-%d')
                    end
                );
drop table part_time
#finding the employee working partime or not
create temporary table part_time
with emp_type
as
(
    select a.* ,b.user_id as intern
    from position_dedup_mnth_name a left join education_dedup_mnth b on (a.Year = b.Year and a.Month = b.Month and a.user_id = b.user_id)
)
select NAME, COMPANY_ID, MAPPED_ROLE, MSA, MONTH, YEAR,IF(intern is not null, 1, 0) as employee_type
from emp_type
order by Name,Year;

select * from part_time;

drop table before_scaling_2;

#joining this data with predicted salaires table to find the predicted salaries of the employees
CREATE TEMPORARY TABLE before_scaling_2
select name, a.msa, Month, a.Year, salary, a.mapped_role, b.employee_type as Employee_Type
from take_home.predicted_salaries a,part_time b
where a.company_id = b.company_id and a.mapped_role = b.mapped_role and a.msa = b.msa and a.year = b.Year;


#joining the above table with scaling weights to finally calculate weighted average salary
CREATE TABLE Task2_Result
select name, msa, Month, Year,  IF(Employee_Type=1,'part-time','full-time') as Employee_Type,sum(salary*weight)/sum(weight) as average_salary
from before_scaling_2 natural join take_home.scaling_weights
group by name, msa, Month, Year, Employee_Type
order by name;



using courses;

# select * from part_time;
#
# alter table position_dedup_mnth_name drop column employee_type;
#
# update position_dedup_mnth_name
# set position_dedup_mnth_name.employee_type = IF((select intern from part_time) is not null, 1, 0)
#
#
# select * from position_dedup_mnth_name;
# select * from take_home.education_dedup;












