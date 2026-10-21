
from suncalc import get_position, get_times
from datetime import datetime
import math
import geocoder
from geopy import distance, Point
import numpy
from geopy.geocoders import Nominatim


class ComputeSunnySide:
    def __init__(self):
        # for now - can calc only for now!
        self.date = datetime.today()
        self.current_lat, self.current_lon = geocoder.ip('me').latlng
        self.geolocator = Nominatim(user_agent='sunnyside')
        self.speeds = {'bus':70, 'train': 100, 'airplane': 900}
        # self.geo_dist = distance

    def get_next_hop(self, curr_lat, curr_lon, dist, bearing):
        start = Point(curr_lat, curr_lon)
        d = distance.distance(kilometers=dist)
        next_hop = d.destination(point=start, bearing=bearing)
        return next_hop

    def get_sunny_angle(self,current_angle, sun_angle):
        # implement the 'right hand rule' on the fly
        left = (current_angle + (360 - sun_angle)) % 360
        right = (sun_angle - current_angle ) % 360
        if left < right:
            return {'direction': 'left', 'azimuth': left}
        return {'direction': 'right', 'azimuth': right}

    def get_side(self, current_location, destination, transport):
        if current_location.lower() == "current location":
            curr_lat, curr_lon = self.current_lat, self.current_lon
        else:
            curr_lat, curr_lon = current_location.latitude, current_location.longitude
        dest_lat, dest_lon = destination.latitude, destination.longitude
        sun_location = self.get_alt_azi(datetime.today(), curr_lon ,curr_lat, verbose=False)
        bearing = self.get_bearing(curr_lat, curr_lon, dest_lat, dest_lon)
        dist = self.get_distance_between_coords((curr_lat, curr_lon), (dest_lat, dest_lon))
        time = dist/self.speeds[transport]
        sunny_out = self.get_sunny_angle(bearing, sun_location['azimuth'])


        # Define a general distance object, initialized with a distance of 1 km.
        #TODO 100 is just general. maybe for a bus? train and ariplane should be different
        #TODO: what is it for? maybe if dist is too far so the sun will go up and down?
        next_hop = self.get_next_hop(curr_lat, curr_lon, 500, bearing)
        # need to compute for every hour and either take an average or.. think about a way to present it!
        # need to calc the time it takes to go there
        if sun_location['altitude'] < 0:
            return 'You are in the dark at the moment!'
        return sunny_out


# get the sun degree based on gps read from current location

    def get_alt_azi(self,date, long, lat, verbose=True):
        if verbose:
            print('Looking for sun agnle in long: {} and lat: {} on date: {}'.format(long,lat,date))
        result = 'Could not find'
        try:
            result = get_position(date, long, lat)
            result['altitude'] = math.degrees(result['altitude'])
            result['azimuth'] = 180 + math.degrees(result['azimuth'])
        except Exception as e:
            print(e)
        return result

    @staticmethod
    def get_distance_between_coords(c1,c2):
        # get distance between two points in km
        return distance.distance(c1, c2).km

    @staticmethod
    def get_bearing(lat1, long1, lat2, long2):
        # get direction between 2 points
        dLon = (long2 - long1)
        x = math.cos(math.radians(lat2)) * math.sin(math.radians(dLon))
        y = math.cos(math.radians(lat1)) * math.sin(math.radians(lat2)) - math.sin(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.cos(math.radians(dLon))
        brng = numpy.arctan2(x,y)
        brng = numpy.degrees(brng)
        # convert to 0-360
        brng = (brng + 360) % 360
        return brng

# date = datetime.today()#datetime(2021, 8, 14, 21 , 19, 8)
# lat, lon = geocoder.ip('me').latlng
# print('You are at {} {}'.format(lat , lon))
# get_alt_azi(date, lon, lat, verbose=True)
#
# # user_agnet = r'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0'
# # user_agnet = 'mountain@gmail.com'
# geolocator = Nominatim(user_agent='sunnyside')
# location2 = geolocator.geocode("Hagilgal 25 st Maale Adumim")
# print(location2.address)
# print((location2.latitude, location2.longitude))
# p=1
