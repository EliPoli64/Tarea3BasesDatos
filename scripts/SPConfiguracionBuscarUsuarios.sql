CREATE OR ALTER PROCEDURE dbo.ConfiguracionBuscarUsuarios
    @inBusqueda         VARCHAR(64)
    , @inUserName       VARCHAR(32)
    , @inIP             VARCHAR(32)
    , @outResultCode    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        SELECT 
            u.ID,
            u.UserName,
            ISNULL(p.ValorDocumentoId, 'N/A') as ValorDocumentoId,
            u.EsActivo
        FROM Usuario u
        LEFT JOIN UsuarioPropietario up ON u.ID = up.IDUsuario
        LEFT JOIN Propietario p ON up.IDPropietario = p.ID
        WHERE u.UserName LIKE '%' + @inBusqueda + '%' 
           OR p.ValorDocumentoId LIKE '%' + @inBusqueda + '%'
        ORDER BY u.UserName;
        
        DECLARE @descBitacora VARCHAR(128) = 'Búsqueda de usuarios: ' + @inBusqueda
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , @descBitacora
            , 2;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
        INSERT INTO dbo.DBError (
			[UserName]
			, [Number]
			, [State]
			, [Severity]
			, [Line]
			, [Procedure]
			, [Message]
			, [DateTime]
		) VALUES (
			SUSER_SNAME()
			, ERROR_NUMBER()
			, ERROR_STATE()
			, ERROR_SEVERITY()
			, ERROR_LINE()
			, ERROR_PROCEDURE()
			, ERROR_MESSAGE()
			, GETDATE()
		);
    END CATCH;
END;
GO