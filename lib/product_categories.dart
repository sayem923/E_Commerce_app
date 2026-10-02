
class ProductCategories {
  static const String others = "Others";

  static const List<String> all = [
    "Gadgets",
    "Fashion",
    "Phones",
    "Book",
    "Home",
    others,
  ];

  
  static List<String> get named => all.where((c) => c != others).toList();

 
  static String get othersFilter =>
      'category.is.null,category.eq.$others,category.not.in.(${named.join(",")})';
}