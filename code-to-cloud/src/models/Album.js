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
    title: "The Power of the Platform",
    artist: "Azure Platform",
    price: 29.99,
    image_url: "https://aka.ms/albums-azurelogo",
  },
  {
    id: 6,
    title: "The Future of Cloud",
    artist: "Cloud Innovators",
    price: 49.99,
    image_url: "https://aka.ms/albums-cloudlogo",
  },
  
];

const getAlbums = async function () {
  return Promise.resolve(albums);
};

exports.getAlbums = getAlbums;
