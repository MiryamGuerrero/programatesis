alter role authenticator in database postgres
set pgrst.db_schemas = 'public,storage,graphql_public,usuarios,clinico,nutricion,interaccion,heuristico,referencia';

alter role authenticator
set pgrst.db_schemas = 'public,storage,graphql_public,usuarios,clinico,nutricion,interaccion,heuristico,referencia';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';
