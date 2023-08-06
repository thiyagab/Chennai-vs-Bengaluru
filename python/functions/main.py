# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn, scheduler_fn, options

#
#
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")


import firebase_functions as functions
import requests
from firebase_admin import initialize_app, firestore
import json
import datetime
import os

app = initialize_app()

functions.options.set_global_options(max_instances=10)

API_KEY = os.getenv('API_KEY')


def compute_routes(origin, destination, waypoints=None):
    """Computes routes between two points and returns the duration and distance in meters."""
    url = "https://routes.googleapis.com/directions/v2:computeRoutes"
    payloadjson = {
        "origin": {
            "location": {
                "latLng": origin
            }
        },
        "destination": {
            "location": {
                "latLng": destination
            }
        },
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
        "languageCode": "en-US",
        "units": "METRIC"
    }
    if waypoints:
        payloadjson['intermediates'] = waypoints
    payload = json.dumps(payloadjson)

    headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': API_KEY,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters'
    }
    response = requests.request("POST", url, headers=headers, data=payload)
    print(response.text)
    if response.status_code == 200:
        return response.json()["routes"][0]
    else:
        return None


@scheduler_fn.on_schedule(schedule="*/15 * * * *")
def my_scheduled_function(event: scheduler_fn.ScheduledEvent) -> None:
    traffic_for_city('chennai')
    traffic_for_city('bengaluru')


def traffic_for_city(city: str):
    routes = firestore.client().collection(city).get()
    speedarray = []
    route_speed_map = []
    for route in routes:
        if route.to_dict().get('origin'):
            origin = {"latitude": route.get('origin').latitude, "longitude": route.get('origin').longitude}
            destination = {"latitude": route.get('destination').latitude,
                           "longitude": route.get('destination').longitude}
            wparray = []
            if route.to_dict().get('waypoints'):
                wps = route.to_dict().get('waypoints')

                for wp in wps:
                    wparray.append({"location": {"latLng": {"latitude": wp.latitude, "longitude": wp.longitude}}})

            calculated_route = compute_routes(origin, destination, wparray)
            duration = int(calculated_route['duration'][:-1])
            distance = calculated_route['distanceMeters']
            speed = (distance / duration) * 3.6
            speedarray.append(speed)
            route_speed_map.append({'route': route.reference, 'speed': round(speed, 2)})

    averagespeed = round((sum(speedarray) / len(speedarray)), 2)
    print('Average Speed: ' + str(averagespeed))
    now = datetime.datetime.now()

    doc_ref = firestore.client().collection("routes").document()
    doc_ref.set({
        "speed": averagespeed,
        "timestamp": now,
        "city": city,
        "routes": route_speed_map
    })


if __name__ == "__main__":
    functions.run_app()

# my_scheduled_function(None)
