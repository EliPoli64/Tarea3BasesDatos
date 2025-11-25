CREATE OR ALTER PROCEDURE dbo.BuscarFincasPorPropietario
    @inValorDocumento   VARCHAR(32)
    , @inUserName         VARCHAR(32)
    , @inIP               VARCHAR(32)
    , @outResultCode      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @tipoEvento INT = 2; -- Consulta
    DECLARE @idUsuario INT;
    DECLARE @idPropietario INT;
    
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Exito: Búsqueda de propiedades por documento ' + @inValorDocumento + ' por usuario ' + @inUserName;

    BEGIN TRY
        SELECT @idUsuario = ID 
        FROM dbo.Usuario 
        WHERE UserName = @inUserName AND EsActivo = 1;

        IF @idUsuario IS NULL
        BEGIN
            SET @outResultCode = 50003; -- Usuario no encontrado
            SET @descripcionEvento = 'Error: Usuario no encontrado en búsqueda por documento';
            RETURN;
        END;

        SELECT @idPropietario = IDPropietario 
        FROM dbo.UsuarioPropietario 
        WHERE IDUsuario = @idUsuario;

        IF @idPropietario IS NULL
        BEGIN
            SET @outResultCode = 50013; -- Usuario no asociado a propietario
            SET @descripcionEvento = 'Error: Usuario no asociado a propietario en búsqueda por documento';
            RETURN;
        END;

        IF NOT EXISTS (
            SELECT 1 
            FROM dbo.Propietario 
            WHERE ID = @idPropietario AND ValorDocumentoId = @inValorDocumento
        )
        BEGIN
            SET @outResultCode = 50014; -- Documento no coincide
            SET @descripcionEvento = 'Error: Documento no coincide con propietario del usuario';
            RETURN;
        END;

        SELECT 
            P.ID,
            P.NumFinca,
            P.Area,
            P.ValorPropiedad,
            TU.Nombre AS TipoUso,
            TA.Nombre AS TipoArea,
            P.FechaRegistro
        FROM dbo.Propiedad P
        INNER JOIN dbo.TipoUsoPropiedad TU ON P.IDTipoUso = TU.ID
        INNER JOIN dbo.TipoAreaPropiedad TA ON P.IDTipoArea = TA.ID
        INNER JOIN dbo.AsociacionPxP AP ON P.ID = AP.IDPropiedad
        WHERE AP.IDPropietario = @idPropietario
            AND AP.FechaFin = '9999-12-31'
            AND AP.IDTipoAsociacion = 1
            AND P.EsActivo = 1
        ORDER BY P.NumFinca;

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento;

    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008; -- error bd
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