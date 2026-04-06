from app.api.v1.route_registry import default_route_registry

api_router = default_route_registry().build_router()
