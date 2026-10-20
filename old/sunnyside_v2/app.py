from flask import Flask, render_template, request, jsonify
from backend_utils import ComputeSunnySide

sunny_side_calculator = ComputeSunnySide()
app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/result', methods=['POST'])
def result():
    location = request.form['location']
    destination = request.form['destination']
    transport = request.form['transport']

    if location.lower() != "current location":
        location = sunny_side_calculator.geolocator.geocode(location)
        if location is None:
            return "Invalid location. Please go back and try again."

    # Get destination lat and lon
    destination = sunny_side_calculator.geolocator.geocode(destination)
    if destination is None:
        return "Invalid destination. Please go back and try again."

    # Get sunny side
    sunny_side = sunny_side_calculator.get_side(location, destination, transport)

    return render_template('result.html', sunny_side=sunny_side)

if __name__ == '__main__':
    app.run(debug=True)