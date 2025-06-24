const albums = [
  {
    id: 1,
    title: "You, Me and an App ID",
    artist: "Daprize",
    price: 56.99,
    image_url: "https://aka.ms/albums-daprlogo",
  },
  {
    id: 2,
    title: "Seven Revision Army",
    artist: "The Blue-Green Stripes",
    price: 17.99,
    image_url: "https://aka.ms/albums-containerappslogo",
  },
  {
    id: 3,
    title: "Scale It Up",
    artist: "KEDA Club",
    price: 39.99,
    image_url: "https://aka.ms/albums-kedalogo",
  },
  {
    id: 4,
    title: "Lost in Translation",
    artist: "MegaDNS",
    price: 39.99,
    image_url: "https://aka.ms/albums-envoylogo",
  },
  {
    id: 5,
    title: "The Container Chronicles",
    artist: "Docker Duo",
    price: 29.99,
    image_url: "https://aka.ms/albums-dockerlogo",
  },
  {
    id: 6,
    title: "Cloudy with a Chance of Containers",
    artist: "Azure Cloud Band",
    price: 49.99,
    image_url: "https://aka.ms/albums-azurelologo",
  },

  
];

const getAlbums = async function () {
  return Promise.resolve(albums);
};

exports.getAlbums = getAlbums;
