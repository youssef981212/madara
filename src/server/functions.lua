local QBCore = exports['qb-core']:GetCoreObject()
SqlFetch = function(statement,payload,callback)
  exports['ghmattimysql']:execute(statement,payload,callback)
end

SqlExecute = function(statement,payload,callback)
  exports['ghmattimysql']:execute(statement,payload,callback)
end