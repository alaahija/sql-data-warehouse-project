/*This script is designed to create a new database called DataWarehouse. It first checks if the database already exists—if so, it drops and recreates it. The script also sets up three essential schemas within the newly created database:

bronze, silver ,gold

Important Warning:
Running this script will permanently delete the DataWarehouse database if it already exists. All data in the existing database will be erased. Ensure proper backups are taken before execution, as the operation cannot be undone.

*/
USE master;
GO

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
