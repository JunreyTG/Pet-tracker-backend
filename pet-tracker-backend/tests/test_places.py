from fastapi.testclient import TestClient

from app.main import app
from app.models.auth import AuthenticatedUser
from app.models.entities import Location
from app.schemas.places import PlaceOptionResponse, PlaceSearchResponse
from app.services.auth_service import get_current_user
from app.services.place_service import PlaceServiceError, get_place_service


client = TestClient(app)


class FakePlaceService:
    def __init__(self, places: list[PlaceSearchResponse] | None = None, should_fail: bool = False) -> None:
        self.places = places if places is not None else [
            PlaceSearchResponse(
                display_name="Barangay 669, Manila, Metro Manila, Philippines",
                location=Location(latitude=14.5995, longitude=120.9842),
            )
        ]
        self.should_fail = should_fail
        self.seen: dict[str, object] | None = None

    def search_places(self, *, country: str, province: str, city: str, barangay: str, limit: int = 5):
        self.seen = {
            "country": country,
            "province": province,
            "city": city,
            "barangay": barangay,
            "limit": limit,
        }
        if self.should_fail:
            raise PlaceServiceError("Place search is not available.")
        return self.places

    def list_countries(self):
        return [PlaceOptionResponse(code="PH", name="Philippines")]

    def list_provinces(self, country_code: str = "PH"):
        self.seen = {"country_code": country_code}
        if self.should_fail:
            raise PlaceServiceError("Place options are not available.")
        return [PlaceOptionResponse(code="130000000", name="National Capital Region")]

    def list_cities(self, province_code: str):
        self.seen = {"province_code": province_code}
        if self.should_fail:
            raise PlaceServiceError("Place options are not available.")
        return [PlaceOptionResponse(code="133900000", name="City of Manila")]

    def list_barangays(self, city_code: str):
        self.seen = {"city_code": city_code}
        if self.should_fail:
            raise PlaceServiceError("Place options are not available.")
        return [PlaceOptionResponse(code="133900001", name="Barangay 1")]


def setup_function() -> None:
    app.dependency_overrides.clear()


def teardown_function() -> None:
    app.dependency_overrides.clear()


def authenticate() -> None:
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="owner-1",
        email="owner@example.com",
        display_name="Owner",
    )


def test_unauthenticated_place_search_returns_401() -> None:
    response = client.get(
        "/api/v1/places/search",
        params={"country": "Philippines", "province": "Metro Manila", "city": "Manila", "barangay": "Barangay 669"},
    )

    assert response.status_code == 401


def test_place_search_returns_matching_places() -> None:
    authenticate()
    service = FakePlaceService()
    app.dependency_overrides[get_place_service] = lambda: service

    response = client.get(
        "/api/v1/places/search",
        params={
            "country": "Philippines",
            "province": "Metro Manila",
            "city": "Manila",
            "barangay": "Barangay 669",
            "limit": "3",
        },
    )

    assert response.status_code == 200
    assert response.json()[0]["location"] == {"latitude": 14.5995, "longitude": 120.9842}
    assert service.seen == {
        "country": "Philippines",
        "province": "Metro Manila",
        "city": "Manila",
        "barangay": "Barangay 669",
        "limit": 3,
    }


def test_place_search_returns_404_when_no_match_exists() -> None:
    authenticate()
    app.dependency_overrides[get_place_service] = lambda: FakePlaceService(places=[])

    response = client.get(
        "/api/v1/places/search",
        params={"country": "Philippines", "province": "Metro Manila", "city": "Manila", "barangay": "Unknown"},
    )

    assert response.status_code == 404


def test_place_search_service_failure_returns_503() -> None:
    authenticate()
    app.dependency_overrides[get_place_service] = lambda: FakePlaceService(should_fail=True)

    response = client.get(
        "/api/v1/places/search",
        params={"country": "Philippines", "province": "Metro Manila", "city": "Manila", "barangay": "Barangay 669"},
    )

    assert response.status_code == 503


def test_place_dropdown_options_are_returned() -> None:
    authenticate()
    service = FakePlaceService()
    app.dependency_overrides[get_place_service] = lambda: service

    countries = client.get("/api/v1/places/countries")
    provinces = client.get("/api/v1/places/provinces", params={"country_code": "PH"})
    cities = client.get("/api/v1/places/cities", params={"province_code": "130000000"})
    barangays = client.get("/api/v1/places/barangays", params={"city_code": "133900000"})

    assert countries.status_code == 200
    assert countries.json() == [{"code": "PH", "name": "Philippines"}]
    assert provinces.status_code == 200
    assert provinces.json() == [{"code": "130000000", "name": "National Capital Region"}]
    assert cities.status_code == 200
    assert cities.json() == [{"code": "133900000", "name": "City of Manila"}]
    assert barangays.status_code == 200
    assert barangays.json() == [{"code": "133900001", "name": "Barangay 1"}]


def test_place_dropdown_options_require_authentication() -> None:
    response = client.get("/api/v1/places/countries")

    assert response.status_code == 401


def test_place_dropdown_service_failure_returns_503() -> None:
    authenticate()
    app.dependency_overrides[get_place_service] = lambda: FakePlaceService(should_fail=True)

    response = client.get("/api/v1/places/cities", params={"province_code": "130000000"})

    assert response.status_code == 503
