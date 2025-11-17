CREATE OR ALTER PROCEDURE dbo.spXML_ProcesarUsuarios
    @Xml XML
    , @inUserName VARCHAR(32)
    , @inIP VARCHAR(32)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @descripcionEvento VARCHAR(256)
    , @resultBitacora INT
    , @tipoEvento INT = 14
    , @BaseID INT;
    
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Éxito: Usuarios procesados correctamente';

    BEGIN TRY
        -- Validaciones iniciales
        IF (@Xml IS NULL OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0)
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: XML de Usuarios está vacío';
            GOTO FinUsuarios;
        END;

        IF (@Xml.exist('/Usuarios/Usuario') = 0)
        BEGIN
            SET @outResultCode = 50012;
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Usuario> en el XML';
            GOTO FinUsuarios;
        END;

        -- Tabla variable para manejo de datos
        DECLARE @UsuariosXML TABLE (
            ValorDocumento VARCHAR(32)
            , TipoUsuario INT
            , TipoAsociacion INT
        );

        INSERT INTO @UsuariosXML (
            ValorDocumento
            , TipoUsuario
            , TipoAsociacion
        )
        SELECT 
            x.value('@ValorDocumentoIdentidad', 'VARCHAR(32)')
            , x.value('@TipoUsuario', 'INT')
            , x.value('@TipoAsociacion', 'INT')
        FROM @Xml.nodes('/Usuarios/Usuario') AS T(x);

        -- Validar existencia de propietarios
        IF EXISTS (
            SELECT 1 
            FROM @UsuariosXML AS U
            LEFT JOIN dbo.Propietario AS P ON P.ValorDocumentoId = U.ValorDocumento
            WHERE (P.ID IS NULL) 
            AND (U.TipoAsociacion = 1)
        )
        BEGIN
            SET @outResultCode = 50001;
            SET @descripcionEvento = 'Error: Se intenta crear usuario sin propietario existente';
            GOTO FinUsuarios;
        END;

        BEGIN TRANSACTION;

        -- Validar duplicados
        IF EXISTS (
            SELECT 1 
            FROM @UsuariosXML AS U
            JOIN dbo.Usuario AS Existing ON Existing.UserName = U.ValorDocumento
            WHERE (U.TipoAsociacion = 1)
        )
        BEGIN
            SET @outResultCode = 50005;
            SET @descripcionEvento = 'Error: Uno o más usuarios ya existen en el sistema';
            ROLLBACK TRANSACTION;
            GOTO FinUsuarios;
        END;

        -- Calculo de ID manual
        SELECT @BaseID = ISNULL(MAX(U.ID), 0) 
        FROM dbo.Usuario AS U;

        DECLARE @NuevosUsuarios TABLE (
            IDGenerado INT
            , UserName VARCHAR(32)
        );

        INSERT INTO dbo.Usuario (
            ID
            , UserName
            , [Password]
            , EsActivo
            , IDTipo
        )
        OUTPUT 
            inserted.ID
            , inserted.UserName 
        INTO @NuevosUsuarios
        SELECT 
            @BaseID + ROW_NUMBER() OVER(ORDER BY U.ValorDocumento)
            , U.ValorDocumento
            , U.ValorDocumento
            , 1
            , U.TipoUsuario
        FROM @UsuariosXML AS U
        WHERE (U.TipoAsociacion = 1);

        INSERT INTO dbo.UsuarioPropietario (
            IDUsuario
            , IDPropietario
        )
        SELECT 
            NU.IDGenerado
            , P.ID
        FROM @NuevosUsuarios AS NU
        JOIN dbo.Propietario AS P ON P.ValorDocumentoId = NU.UserName;

        -- Procesar bajas
        UPDATE U
        SET EsActivo = 0
        FROM dbo.Usuario AS U
        JOIN @UsuariosXML AS X ON X.ValorDocumento = U.UserName
        WHERE (X.TipoAsociacion = 2);

        COMMIT TRANSACTION;

FinUsuarios:
        IF (@outResultCode <> 0)
        BEGIN
            SET @tipoEvento = 11;
        END

        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , @descripcionEvento
            , @tipoEvento
            , @outResultCode = @resultBitacora OUTPUT;

    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0) 
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50008;

        INSERT INTO dbo.DBError (
            UserName
            , Number
            , State
            , Severity
            , Line
            , Procedure
            , Message
            , DateTime
        )
        VALUES (
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

    SET NOCOUNT OFF;
END;