CREATE OR ALTER PROCEDURE dbo.ObtenerDescripcionError
    @inCodigo           INT
    , @outDescripcion   VARCHAR(256) OUTPUT
AS
BEGIN  
    SET NOCOUNT ON;
    SET @outDescripcion = NULL;

    SELECT @outDescripcion = E.Descripcion
    FROM dbo.Error E
    WHERE E.Codigo = @inCodigo;

    IF @outDescripcion IS NULL
    BEGIN
        SET @outDescripcion = 'Error desconocido';
    END
END;