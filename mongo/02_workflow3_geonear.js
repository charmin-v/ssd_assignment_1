// =====================================================
// WORKFLOW 3
// Find the closest active driver within 5 KM
// =====================================================


// Example restaurant coordinates.
// GeoJSON uses [LONGITUDE, LATITUDE].

const restaurantLongitude = 77.5946;
const restaurantLatitude = 12.9716;


db.DriverPings.aggregate([

    {
        $geoNear: {

            near: {
                type: "Point",

                coordinates: [
                    restaurantLongitude,
                    restaurantLatitude
                ]
            },

            key: "location",

            distanceField: "distanceMeters",

            maxDistance: 5000,

            spherical: true,

            query: {
                active: true
            }
        }
    },


    // Closest driver only.

    {
        $limit: 1
    },


    {
        $project: {

            _id: 0,

            driverId: 1,

            active: 1,

            distanceMeters: 1,

            location: 1,

            createdAt: 1
        }
    }

]);