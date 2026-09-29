import logging
from time import monotonic

import httpx

from app.models.entities import Location
from app.schemas.places import PlaceOptionResponse, PlaceSearchResponse

logger = logging.getLogger(__name__)


class PlaceServiceError(RuntimeError):
    """Raised when place search cannot be completed."""


class PlaceService:
    psgc_base_url = "https://psgc.gitlab.io/api"
    psgc_cache_ttl_seconds = 60 * 60 * 24 * 7
    search_cache_ttl_seconds = 60 * 60 * 24
    _psgc_cache: dict[str, tuple[float, list[object]]] = {}
    _search_cache: dict[str, tuple[float, list[PlaceSearchResponse]]] = {}

    def list_countries(self) -> list[PlaceOptionResponse]:
        return [PlaceOptionResponse(code="PH", name="Philippines")]

    def list_provinces(self, country_code: str = "PH") -> list[PlaceOptionResponse]:
        if country_code.upper() != "PH":
            return []

        provinces = self._get_psgc_options("/provinces/")
        regions = self._get_psgc_payload("/regions/")
        metro_manila = [
            PlaceOptionResponse(code=str(region["code"]), name=str(region["name"]))
            for region in regions
            if isinstance(region, dict) and str(region.get("code")) == "130000000"
        ]
        return sorted([*metro_manila, *provinces], key=lambda place: place.name)

    def list_cities(self, province_code: str) -> list[PlaceOptionResponse]:
        if province_code == "130000000":
            return self._get_psgc_options(f"/regions/{province_code}/cities-municipalities/")
        return self._get_psgc_options(f"/provinces/{province_code}/cities-municipalities/")

    def list_barangays(self, city_code: str) -> list[PlaceOptionResponse]:
        return self._get_psgc_options(f"/cities-municipalities/{city_code}/barangays/")

    def search_places(
        self,
        *,
        country: str,
        province: str,
        city: str,
        barangay: str,
        limit: int = 5,
    ) -> list[PlaceSearchResponse]:
        query = ", ".join([barangay.strip(), city.strip(), province.strip(), country.strip()])
        cache_key = f"{query}|{limit}"
        cached = self._search_cache.get(cache_key)
        if cached is not None and cached[0] > monotonic():
            return list(cached[1])

        try:
            response = httpx.get(
                "https://nominatim.openstreetmap.org/search",
                params={"format": "json", "limit": limit, "q": query},
                headers={"User-Agent": "pet-tracker-backend/0.1.0"},
                timeout=15,
            )
            response.raise_for_status()
            payload = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            logger.info("Place search failed: %s", exc.__class__.__name__)
            raise PlaceServiceError("Place search is not available.") from exc

        if not isinstance(payload, list):
            raise PlaceServiceError("Place search returned an invalid response.")

        places: list[PlaceSearchResponse] = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            try:
                places.append(
                    PlaceSearchResponse(
                        display_name=str(item["display_name"]),
                        location=Location(latitude=float(item["lat"]), longitude=float(item["lon"])),
                    )
                )
            except (KeyError, TypeError, ValueError):
                continue

        self._search_cache[cache_key] = (monotonic() + self.search_cache_ttl_seconds, places)
        return places

    def _get_psgc_options(self, path: str) -> list[PlaceOptionResponse]:
        payload = self._get_psgc_payload(path)
        options: list[PlaceOptionResponse] = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            code = item.get("code")
            name = item.get("name")
            if code is None or name is None:
                continue
            options.append(PlaceOptionResponse(code=str(code), name=str(name)))
        return sorted(options, key=lambda place: place.name)

    def _get_psgc_payload(self, path: str) -> list[object]:
        cached = self._psgc_cache.get(path)
        if cached is not None and cached[0] > monotonic():
            return list(cached[1])

        try:
            response = httpx.get(f"{self.psgc_base_url}{path}", timeout=20)
            response.raise_for_status()
            payload = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            logger.info("PSGC place option lookup failed: %s", exc.__class__.__name__)
            raise PlaceServiceError("Place options are not available.") from exc

        if not isinstance(payload, list):
            raise PlaceServiceError("Place options returned an invalid response.")

        self._psgc_cache[path] = (monotonic() + self.psgc_cache_ttl_seconds, payload)
        return payload


def get_place_service() -> PlaceService:
    return PlaceService()
