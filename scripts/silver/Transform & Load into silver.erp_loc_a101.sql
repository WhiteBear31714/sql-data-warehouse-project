-- Transform & Load into silver.erp_loc_a101

PRINT '>> Truncating Table: silver.erp_loc_a101';
TRUNCATE TABLE silver.erp_loc_a101;
PRINT '>> Inserting Data Into: silver.erp_loc_a101'

INSERT INTO silver.erp_loc_a101(
	cid,
	cntry
)

SELECT 
	REPLACE(cid, '-', '') cid, -- ลบสัญลักษณ์ '-' ให้เป็นค่าว่าง 
	CASE WHEN TRIM(cntry) = 'DE' THEN 'Gerney'
		 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
		 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
	END AS cntry
FROM bronze.erp_loc_a101


