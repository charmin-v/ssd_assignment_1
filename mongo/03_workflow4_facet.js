// =====================================================
// WORKFLOW 4
// Review analytics using $facet
// =====================================================


db.Reviews.aggregate([

    {
        $facet: {


            ratingDistribution: [

                {
                    $group: {

                        _id: "$rating",

                        count: {
                            $sum: 1
                        }
                    }
                },

                {
                    $sort: {
                        _id: 1
                    }
                }
            ],
            tagFrequency: [

                {
                    $unwind: "$sentimentTags"
                },

                {
                    $group: {

                        _id: "$sentimentTags",

                        count: {
                            $sum: 1
                        }
                    }
                },

                {
                    $sort: {

                        count: -1,

                        _id: 1
                    }
                }
            ],
            overallAverage: [

                {
                    $group: {

                        _id: null,

                        averageRating: {
                            $avg: "$rating"
                        },

                        totalReviews: {
                            $sum: 1
                        }
                    }
                },

                {
                    $project: {

                        _id: 0,

                        averageRating: {
                            $round: [
                                "$averageRating",
                                2
                            ]
                        },

                        totalReviews: 1
                    }
                }
            ]
        }
    }

]);