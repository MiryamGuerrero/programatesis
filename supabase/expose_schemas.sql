alter role authenticator set pgrst.db_schemas = 'public,storage,graphql_public,usuarios,clinico,nutricion,interaccion,heuristico,referencia';
notify pgrst, 'reload config';
